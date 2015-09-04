# coding: utf-8
$:.unshift "."
require 'spec_helper'
require 'rdf/spec/reader'

describe "RDF::Turtle::Reader" do
  before(:each) {$stderr, @old_stderr = StringIO.new, $stderr}
  after(:each) {$stderr = @old_stderr}
  let!(:doap) {File.expand_path("../../etc/doap.ttl", __FILE__)}
  let!(:doap_nt) {File.expand_path("../../etc/doap.nt", __FILE__)}
  let!(:doap_count) {File.open(doap_nt).each_line.to_a.length}

  it_behaves_like 'an RDF::Reader' do
    let(:reader) {RDF::Turtle::Reader.new}
    let(:reader_input) {File.read(doap)}
    let(:reader_count) {doap_count}
  end

  describe ".for" do
    formats = [
      :turtle,
      'etc/doap.ttl',
      {file_name:       'etc/doap.ttl'},
      {file_extension:  'ttl'},
      {content_type:    'text/turtle'},
      {content_type:    'application/turtle'},
      {content_type:    'application/x-turtle'},
    ].each do |arg|
      it "discovers with #{arg.inspect}" do
        expect(RDF::Reader.for(arg)).to eq RDF::Turtle::Reader
      end
    end
  end

  context :interface do
    subject {
      %q(
        @base <http://example/> .
        <a> <b> [
          a <C>, <D>;
          <has> ("e" <f> _:g)
        ] .
      )
    }
    
    it "should yield reader" do
      inner = double("inner")
      expect(inner).to receive(:called).with(RDF::Turtle::Reader)
      RDF::Turtle::Reader.new(subject) do |reader|
        inner.called(reader.class)
      end
    end
    
    it "should return reader" do
      expect(RDF::Turtle::Reader.new(subject)).to be_a(RDF::Turtle::Reader)
    end
    
    context "with :freebase option" do
      it "returns a FreebaseReader instance" do
        r = RDF::Turtle::Reader.new(StringIO.new(""), freebase:  true)
        expect(r).to be_a(RDF::Turtle::FreebaseReader)
      end
    end

    it "should not raise errors" do
      expect {
        RDF::Turtle::Reader.new(subject, validate:  true)
      }.not_to raise_error
    end

    it "should yield statements" do
      inner = double("inner")
      expect(inner).to receive(:called).with(RDF::Statement).exactly(10)
      RDF::Turtle::Reader.new(subject).each_statement do |statement|
        inner.called(statement.class)
      end
    end
    
    it "should yield triples" do
      inner = double("inner")
      expect(inner).to receive(:called).exactly(10)
      RDF::Turtle::Reader.new(subject).each_triple do |subject, predicate, object|
        inner.called(subject.class, predicate.class, object.class)
      end
    end
  end

  describe "with simple ntriples" do
    context "simple triple" do
      before(:each) do
        ttl_string = %(<http://example/> <http://xmlns.com/foaf/0.1/name> "Gregg Kellogg" .)
        @graph = parse(ttl_string, validate:  true)
        @statement = @graph.statements.to_a.first
      end
      
      it "should have a single triple" do
        expect(@graph.size).to eq 1
      end
      
      it "should have subject" do
        expect(@statement.subject.to_s).to eq "http://example/"
      end
      it "should have predicate" do
        expect(@statement.predicate.to_s).to eq "http://xmlns.com/foaf/0.1/name"
      end
      it "should have object" do
        expect(@statement.object.to_s).to eq "Gregg Kellogg"
      end
    end
    
    # NTriple tests from http://www.w3.org/2000/10/rdf-tests/rdfcore/ntriples/test.nt
    describe "with blank lines" do
      {
        "comment"                   => "# comment lines",
        "comment after whitespace"  => "            # comment after whitespace",
        "empty line"                => "",
        "line with spaces"          => "      "
      }.each_pair do |name, statement|
        specify "test #{name}" do
          expect(parse(statement).size).to eq 0
        end
      end
    end

    describe "with literal encodings" do
      {
        'simple literal' => '<a> <b>  "simple literal" .',
        'backslash:\\'   => '<a> <b>  "backslash:\\\\" .',
        'dquote:"'       => '<a> <b>  "dquote:\\"" .',
        "newline:\n"     => '<a> <b>  "newline:\\n" .',
        "return\r"       => '<a> <b>  "return\\r" .',
        "tab:\t"         => '<a> <b>  "tab:\\t" .',
      }.each_pair do |contents, triple|
        specify "test #{triple}" do
          graph = parse(triple, prefixes:  {nil => ''})
          statement = graph.statements.to_a.first
          expect(graph.size).to eq 1
          expect(statement.object.value).to eq contents
        end
      end
      
      # Rubinius problem with UTF-8 indexing:
      # "\"D\xC3\xBCrst\""[1..-2] => "D\xC3\xBCrst\""
      {
        'Dürst' => '<a> <b> "Dürst" .',
        "é" => '<a> <b>  "é" .',
        "€" => '<a> <b>  "€" .',
        "resumé" => ':a :resume  "resumé" .',
      }.each_pair do |contents, triple|
        specify "test #{triple}" do
          graph = parse(triple, prefixes:  {nil => ''})
          statement = graph.statements.to_a.first
          expect(graph.size).to eq 1
          expect(statement.object.value).to eq contents
        end
      end
      
      it "should parse long literal with escape" do
        ttl = %(@prefix : <http://example/foo#> . <a> <b> "\\U00015678another" .)
        statement = parse(ttl).statements.to_a.first
        expect(statement.object.value).to eq "\u{15678}another"
      end
      
      context "STRING_LITERAL_LONG" do
        {
          "simple" => %q(foo),
          "muti-line" => %q(
            Foo
            <html:b xmlns:html="http://www.w3.org/1999/xhtml" html:a="b">
              bar
              <rdf:Thing xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#">
                <a:b xmlns:a="foo:"></a:b>
                here
                <a:c xmlns:a="foo:"></a:c>
              </rd
              f:Thing>
            </html:b>
            baz
            <html:i xmlns:html="http://www.w3.org/1999/xhtml">more</html:i>
          ),
        }.each do |test, string|
          it "parses LONG1 #{test}" do
            graph = parse(%(<a> <b> '''#{string}'''.))
            expect(graph.size).to eq 1
            expect(graph.statements.to_a.first.object.value).to eq string
          end

          it "parses LONG2 #{test}" do
            graph = parse(%(<a> <b> """#{string}""".))
            expect(graph.size).to eq 1
            expect(graph.statements.to_a.first.object.value).to eq string
          end
        end
      end
      
      it "LONG1 matches trailing escaped single-quote" do
        graph = parse(%(<a> <b> '''\\''''.))
        expect(graph.size).to eq 1
        expect(graph.statements.to_a.first.object.value).to eq %q(')
      end
      
      it "LONG2 matches trailing escaped double-quote" do
        graph = parse(%(<a> <b> """\\"""".))
        expect(graph.size).to eq 1
        expect(graph.statements.to_a.first.object.value).to eq %q(")
      end
    end

    it "should create named subject bnode" do
      graph = parse("_:anon <http://example/property> <http://example/resource2> .")
      expect(graph.size).to eq 1
      statement = graph.statements.to_a.first
      expect(statement.subject).to be_a(RDF::Node)
      expect(statement.subject.id).to match /anon/
      expect(statement.predicate.to_s).to eq "http://example/property"
      expect(statement.object.to_s).to eq "http://example/resource2"
    end

    it "raises error with anonymous predicate" do
      expect {
        parse("<http://example/resource2> _:anon <http://example/object> .", validate:  true)
      }.to raise_error RDF::ReaderError
    end

    it "ignores anonymous predicate" do
      g = parse("<http://example/resource2> _:anon <http://example/object> .", validate:  false)
      expect(g).to be_empty
    end

    it "should create named object bnode" do
      graph = parse("<http://example/resource2> <http://example/property> _:anon .")
      expect(graph.size).to eq 1
      statement = graph.statements.to_a.first
      expect(statement.subject.to_s).to eq "http://example/resource2"
      expect(statement.predicate.to_s).to eq "http://example/property"
      expect(statement.object).to be_a(RDF::Node)
      expect(statement.object.id).to match /anon/
    end

    it "should allow mixed-case language" do
      ttl = %(:x2 :p "xyz"@EN .)
      statement = parse(ttl, prefixes:  {nil => ''}).statements.to_a.first
      expect(statement.object.to_ntriples).to eq %("xyz"@EN)
    end

    it "should create typed literals" do
      ttl = "<http://example/joe> <http://xmlns.com/foaf/0.1/name> \"Joe\" ."
      statement = parse(ttl).statements.to_a.first
      expect(statement.object.class).to eq RDF::Literal
    end

    it "should create BNodes" do
      ttl = "_:a a _:c ."
      statement = parse(ttl).statements.to_a.first
      expect(statement.subject.class).to eq RDF::Node
      expect(statement.object.class).to eq RDF::Node
    end

    describe "IRIs" do
      {
        %(<http://example/joe> <http://xmlns.com/foaf/0.1/knows> <http://example/jane> .) =>
          %(<http://example/joe> <http://xmlns.com/foaf/0.1/knows> <http://example/jane> .),
        %(@base <http://a/b> . <joe> <knows> <#jane> .) =>
          %(<http://a/joe> <http://a/knows> <http://a/b#jane> .),
        %(@base <http://a/b#> . <joe> <knows> <#jane> .) =>
          %(<http://a/joe> <http://a/knows> <http://a/b#jane> .),
        %(@base <http://a/b/> . <joe> <knows> <#jane> .) =>
          %(<http://a/b/joe> <http://a/b/knows> <http://a/b/#jane> .),
        %(@base <http://a/b/> . </joe> <knows> <jane> .) =>
          %(<http://a/joe> <http://a/b/knows> <http://a/b/jane> .),
        %(<http://example/#D%C3%BCrst>  a  "URI percent ^encoded as C3, BC".) =>
          %(<http://example/#D%C3%BCrst> <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> "URI percent ^encoded as C3, BC" .),
        %q(<http://example/node> <http://example/prop> <scheme:!$%25&'()*+,-./0123456789:/@ABCDEFGHIJKLMNOPQRSTUVWXYZ_abcdefghijklmnopqrstuvwxyz~?#> .) =>
          %q(<http://example/node> <http://example/prop> <scheme:!$%25&'()*+,-./0123456789:/@ABCDEFGHIJKLMNOPQRSTUVWXYZ_abcdefghijklmnopqrstuvwxyz~?#> .),
      }.each_pair do |ttl, nt|
        it "for '#{ttl}'" do
          expect(parse(ttl, validate:  true)).to be_equivalent_graph(nt, trace:  @debug)
        end
      end

      {
        %(<#Dürst> <knows> <jane>.) => '<#D\u00FCrst> <knows> <jane> .',
        %(<Dürst> <knows> <jane>.) => '<D\u00FCrst> <knows> <jane> .',
        %(<bob> <resumé> "Bob's non-normalized resumé".) => '<bob> <resumé> "Bob\'s non-normalized resumé" .',
        %(<alice> <resumé> "Alice's normalized resumé".) => '<alice> <resumé> "Alice\'s normalized resumé" .',
        }.each_pair do |ttl, nt|
          it "for '#{ttl}'" do
            expect(parse(ttl)).to be_equivalent_graph(nt, trace:  @debug)
          end
        end

      {
        %(<#Dürst> a  "URI straight in UTF8".) => %(<#D\\u00FCrst> <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> "URI straight in UTF8" .),
        %(<a> :related :ひらがな .) => %(<a> <related> <\\u3072\\u3089\\u304C\\u306A> .),
      }.each_pair do |ttl, nt|
        it "for '#{ttl}'" do
          expect(parse(ttl, prefixes:  {nil => ''})).to be_equivalent_graph(nt, trace:  @debug)
        end
      end

      [
        %(\x00),
        %(\x01),
        %(\x0f),
        %(\x10),
        %(\x1f),
        %(\x20),
        %(<),
        %(>),
        %("),
        %({),
        %(}),
        %(|),
        %(\\),
        %(^),
        %(``),
        %(http://example.com/\u0020),
        %(http://example.com/\u003C),
        %(http://example.com/\u003E),
      ].each do |uri|
        it "rejects #{('<' + uri + '>').inspect}" do
          expect {parse(%(<s> <p> <#{uri}>), validate:  true)}.to raise_error RDF::ReaderError
        end
      end
    end
  end
  
  describe "with turtle grammar" do
    describe "syntactic expressions" do
      it "typed literals" do
        ttl = %(
          @prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
          @prefix foaf: <http://xmlns.com/foaf/0.1/> .
          @prefix xsd: <http://www.w3.org/2001/XMLSchema#> .
          <http://example/joe> foaf:name \"Joe\"^^xsd:string .
        )
        statement = parse(ttl).statements.to_a.first
        expect(statement.object.class).to eq RDF::Literal
      end

      it "rdf:type for 'a'" do
        ttl = %(@prefix a: <http://foo/a#> . a:b a <http://www.w3.org/2000/01/rdf-schema#resource> .)
        nt = %(<http://foo/a#b> <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> <http://www.w3.org/2000/01/rdf-schema#resource> .)
        expect(parse(ttl)).to be_equivalent_graph(nt, trace:  @debug)
      end

      {
        %(<a> <b> true .)  => %(<a> <b> "true"^^<http://www.w3.org/2001/XMLSchema#boolean> .),
        %(<a> <b> false .)  => %(<a> <b> "false"^^<http://www.w3.org/2001/XMLSchema#boolean> .),
        %(<a> <b> 1 .)  => %(<a> <b> "1"^^<http://www.w3.org/2001/XMLSchema#integer> .),
        %(<a> <b> -1 .)  => %(<a> <b> "-1"^^<http://www.w3.org/2001/XMLSchema#integer> .),
        %(<a> <b> +1 .)  => %(<a> <b> "+1"^^<http://www.w3.org/2001/XMLSchema#integer> .),
        %(<a> <b> .1 .)  => %(<a> <b> "0.1"^^<http://www.w3.org/2001/XMLSchema#decimal> .),
        %(<a> <b> 1.0 .)  => %(<a> <b> "1.0"^^<http://www.w3.org/2001/XMLSchema#decimal> .),
        %(<a> <b> 1.0e1 .)  => %(<a> <b> "1.0e1"^^<http://www.w3.org/2001/XMLSchema#double> .),
        %(<a> <b> 1.0e-1 .)  => %(<a> <b> "1.0e-1"^^<http://www.w3.org/2001/XMLSchema#double> .),
        %(<a> <b> 1.0e+1 .)  => %(<a> <b> "1.0e+1"^^<http://www.w3.org/2001/XMLSchema#double> .),
        %(<a> <b> 1.0E1 .)  => %(<a> <b> "1.0e1"^^<http://www.w3.org/2001/XMLSchema#double> .),
        %(<a> <b> 123.E+1 .)  => %(<a> <b> "123.0E+1"^^<http://www.w3.org/2001/XMLSchema#double> .),
      }.each_pair do |ttl, nt|
        it "should create typed literal for '#{ttl}'" do
          expect(parse(ttl)).to be_equivalent_graph(nt, trace:  @debug)
        end
      end
      
      it "should accept empty localname" do
        ttl1 = %(@prefix : <> .: : : .)
        ttl2 = %(<> <> <> .)
        g2 = parse(ttl2)
        expect(parse(ttl1)).to be_equivalent_graph(g2, trace:  @debug)
      end
      
      it "should accept prefix with empty local name" do
        ttl = %(@prefix foo: <http://foo/bar#> . foo: foo: foo: .)
        nt = %(<http://foo/bar#> <http://foo/bar#> <http://foo/bar#> .)
        expect(parse(ttl)).to be_equivalent_graph(nt, trace:  @debug)
      end
    end
    
    describe "@prefix" do
      it "raises an error when validating if not defined" do
        ttl = %(<a> a :a .)
        expect(lambda {parse(ttl, validate:  true)}).to raise_error(RDF::ReaderError)
      end
      
      it "allows undefined empty prefix if not validating" do
        ttl = %(:a :b :c .)
        nt = %(<a> <b> <c> .)
        expect(parse(":a :b :c", validate:  false)).to be_equivalent_graph(nt, trace:  @debug)
      end

      it "empty relative-IRI" do
        ttl = %(@prefix foo: <> . <a> a foo:a.)
        nt = %(<a> <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> <a> .)
        expect(parse(ttl)).to be_equivalent_graph(nt, trace:  @debug)
      end

      it "<#> as a prefix and as a triple node" do
        ttl = %(@prefix : <#> . <#> a :a.)
        nt = %(
        <#> <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> <#a> .
        )
        expect(parse(ttl)).to be_equivalent_graph(nt, trace:  @debug)
      end
      
      it "ignores _ as @prefix identifier" do
        ttl = %(
        _:a a :p.
        @prefix _: <http://underscore/> .
        _:a a :q.
        )
        nt = %(
        _:a <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> <p> .
        _:a <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> <q> .
        )
        expect {parse(ttl, validate:  true)}.to raise_error(RDF::ReaderError)
        expect(parse(ttl, validate:  false)).to be_equivalent_graph(nt, trace:  @debug)
      end

      it "redefine" do
        ttl = %(
        @prefix a: <http://host/A#>.
        a:b a:p a:v .

        @prefix a: <http://host/Z#>.
        a:b a:p a:v .
        )
        nt = %(
        <http://host/A#b> <http://host/A#p> <http://host/A#v> .
        <http://host/Z#b> <http://host/Z#p> <http://host/Z#v> .
        )
        expect(parse(ttl)).to be_equivalent_graph(nt, trace:  @debug)
      end

      it "returns defined prefixes" do
        ttl = %(
        @prefix rdf:  <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
        @prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#> .
        @prefix : <http://test/> .
        :foo a rdfs:Class.
        :bar :d :c.
        :a :d :c.
        )
        reader = RDF::Turtle::Reader.new(ttl)
        reader.each {|statement|}
        expect(reader.prefixes).to eq({
          rdf:  "http://www.w3.org/1999/02/22-rdf-syntax-ns#",
          rdfs:  "http://www.w3.org/2000/01/rdf-schema#",
          nil => "http://test/"})
      end

      {
        "@prefix foo: <http://foo/bar#> ." => true,
        "@PrEfIx foo: <http://foo/bar#> ." => false,
        "prefix foo: <http://foo/bar#> ." => false,
        "PrEfIx foo: <http://foo/bar#> ." => false,
        "@prefix foo: <http://foo/bar#>" => false,
        "@PrEfIx foo: <http://foo/bar#>" => false,
        "prefix foo: <http://foo/bar#>" => true,
        "PrEfIx foo: <http://foo/bar#>" => true,
      }.each do |prefix, valid|
        context prefix do
          it "sets prefix" do
            ttl = %(#{prefix} <a> a foo:a.)
            nt = %(<a> <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> <http://foo/bar#a> .)
            expect(parse(ttl)).to be_equivalent_graph(nt, trace:  @debug)
          end

          specify do
            ttl = %(#{prefix} <http://example/> a foo:a.)
            if valid
              expect {parse(ttl, validate:  true)}.not_to raise_error
            else
              expect {parse(ttl, validate:  true)}.to raise_error
            end
          end
        end
      end
    end

    describe "@base" do
      it "sets absolute base" do
        ttl = %(@base <http://foo/bar> . <> <a> <b> . <#c> <d> </e>.)
        nt = %(
        <http://foo/bar> <http://foo/a> <http://foo/b> .
        <http://foo/bar#c> <http://foo/d> <http://foo/e> .
        )
        expect(parse(ttl)).to be_equivalent_graph(nt, trace:  @debug)
      end
      
      it "sets absolute base (trailing /)" do
        ttl = %(@base <http://foo/bar/> . <> <a> <b> . <#c> <d> </e>.)
        nt = %(
        <http://foo/bar/> <http://foo/bar/a> <http://foo/bar/b> .
        <http://foo/bar/#c> <http://foo/bar/d> <http://foo/e> .
        )
        expect(parse(ttl)).to be_equivalent_graph(nt, trace:  @debug)
      end
      
      it "should set absolute base (trailing #)" do
        ttl = %(@base <http://foo/bar#> . <> <a> <b> . <#c> <d> </e>.)
        nt = %(
        <http://foo/bar#> <http://foo/a> <http://foo/b> .
        <http://foo/bar#c> <http://foo/d> <http://foo/e> .
        )
        expect(parse(ttl)).to be_equivalent_graph(nt, trace:  @debug)
      end
      
      it "sets a relative base" do
        ttl = %(
        @base <http://example/products/>.
        <> <a> <b>, <#c>.
        @base <prod123/>.
        <> <a> <b>, <#c>.
        @base <../>.
        <> <a> <d>, <#e>.
        )
        nt = %(
        <http://example/products/> <http://example/products/a> <http://example/products/b> .
        <http://example/products/> <http://example/products/a> <http://example/products/#c> .
        <http://example/products/prod123/> <http://example/products/prod123/a> <http://example/products/prod123/b> .
        <http://example/products/prod123/> <http://example/products/prod123/a> <http://example/products/prod123/#c> .
        <http://example/products/> <http://example/products/a> <http://example/products/d> .
        <http://example/products/> <http://example/products/a> <http://example/products/#e> .
        )
        expect(parse(ttl)).to be_equivalent_graph(nt, trace:  @debug)
      end
      
      it "redefine" do
        ttl = %(
        @base <http://example.com/ontolgies>. <a> <b> <foo/bar#baz>.
        @base <path/DIFFERENT/>. <a2> <b2> <foo/bar#baz2>.
        @prefix : <#>. <d3> :b3 <e3>.
        )
        nt = %(
        <http://example.com/a> <http://example.com/b> <http://example.com/foo/bar#baz> .
        <http://example.com/path/DIFFERENT/a2> <http://example.com/path/DIFFERENT/b2> <http://example.com/path/DIFFERENT/foo/bar#baz2> .
        <http://example.com/path/DIFFERENT/d3> <http://example.com/path/DIFFERENT/#b3> <http://example.com/path/DIFFERENT/e3> .
        )
        expect(parse(ttl)).to be_equivalent_graph(nt, trace:  @debug)
      end

      {
        "@base <http://foo/bar> ." => true,
        "@BaSe <http://foo/bar> ." => false,
        "base <http://foo/bar> ." => false,
        "BaSe <http://foo/bar> ." => false,
        "@base <http://foo/bar>" => false,
        "@BaSe <http://foo/bar>" => false,
        "base <http://foo/bar>" => true,
        "BaSe <http://foo/bar>" => true,
      }.each do |base, valid|
        context base do
          it "sets base" do
            ttl = %(#{base} <> <a> <b> . <#c> <d> </e>.)
            nt = %(
            <http://foo/bar> <http://foo/a> <http://foo/b> .
            <http://foo/bar#c> <http://foo/d> <http://foo/e> .
            )
            expect(parse(ttl)).to be_equivalent_graph(nt, trace:  @debug)
          end

          if valid
            specify do
              ttl = %(#{base} <> <a> <b> . <#c> <d> </e>.)
              expect {parse(ttl, validate:  true)}.not_to raise_error
            end
          else
            specify do
              ttl = %(#{base} <> <a> <b> . <#c> <d> </e>.)
              expect {parse(ttl, validate:  true)}.to raise_error
            end
          end
        end
      end
    end
    
    describe "BNodes" do
      it "should create BNode for identifier with '_' prefix" do
        ttl = %(@prefix a: <http://foo/a#> . _:a a:p a:v .)
        nt = %(_:bnode0 <http://foo/a#p> <http://foo/a#v> .)
        expect(parse(ttl)).to be_equivalent_graph(nt, trace:  @debug)
      end
      
      it "should create BNode for [] as subject" do
        ttl = %(@prefix a: <http://foo/a#> . [] a:p a:v .)
        nt = %(_:bnode0 <http://foo/a#p> <http://foo/a#v> .)
        g = parse(ttl, base_uri:  "http://a/b")
        expect(g).to be_equivalent_graph(nt, about:  "http://a/b", trace:  @debug)
      end
      
      it "raises error for [] as predicate" do
        ttl = %(@prefix a: <http://foo/a#> . a:s [] a:o .)
        expect {parse(ttl, validate:  true)}.to raise_error RDF::ReaderError
      end
      
      it "should not create BNode for [] as predicate" do
        ttl = %(@prefix a: <http://foo/a#> . a:s [] a:o .)
        expect(parse(ttl, validate:  false)).to be_empty
      end
      
      it "should create BNode for [] as object" do
        ttl = %(@prefix a: <http://foo/a#> . a:s a:p [] .)
        nt = %(<http://foo/a#s> <http://foo/a#p> _:bnode0 .)
        expect(parse(ttl)).to be_equivalent_graph(nt, trace:  @debug)
      end
      
      it "creates BNode for [] as statement" do
        ttl = %([<a> <b>] .)
        nt = %(_:a <a> <b> .)
        expect(parse(ttl, validate:  false)).to be_equivalent_graph(nt, trace:  @debug)
      end
      
      it "should create BNode as a single object" do
        ttl = %q(@prefix a: <http://foo/a#> . a:b a:oneRef [ a:pp "1" ; a:qq "2" ] .)
        nt = %(
        _:a <http://foo/a#pp> "1" .
        _:a <http://foo/a#qq> "2" .
        <http://foo/a#b> <http://foo/a#oneRef> _:a .
        )
        expect(parse(ttl, validate:  false)).to be_equivalent_graph(nt, trace:  @debug)
      end
      
      it "should create a shared BNode" do
        ttl = %(
        :b1 :twoRef _:a .
        :b2 :twoRef _:a .

        _:a :pred [ :pp "1" ; :qq "2" ].
        )
        nt = %(
        <b1> <twoRef> _:a .
        <b2> <twoRef> _:a .
        _:b <pp> "1" .
        _:b <qq> "2" .
        _:a <pred> _:b .
        )
        expect(parse(ttl, prefixes:  {nil => ''})).to be_equivalent_graph(nt, trace:  @debug)
      end
      
      it "should create nested BNodes" do
        ttl = %(
        :a :p [ :p2 [ :p3 "v1" , "v2" ; :p4 "v3" ] ; :p5 "v4" ] .
        )
        nt = %(
        <a> <p> _:a .
        _:a <p2> _:b .
        _:a <p5> "v4" .
        _:b <p3> "v1" .
        _:b <p3> "v2" .
        _:b <p4> "v3" .
        )
        expect(parse(ttl, prefixes:  {nil => ''})).to be_equivalent_graph(nt, trace:  @debug)
      end
    end
    
    describe "objectList" do
      it "IRIs" do
        ttl = %(<a> <b> <c>, <d>.)
        nt = %(
          <a> <b> <c> .
          <a> <b> <d> .
        )
        expect(parse(ttl)).to be_equivalent_graph(nt, trace:  @debug)
      end

      it "literals" do
        ttl = %(<a> <b> "1", "2" .)
        nt = %(
          <a> <b> "1" .
          <a> <b> "2" .
        )
        expect(parse(ttl)).to be_equivalent_graph(nt, trace:  @debug)
      end

      it "mixed" do
        ttl = %(<a> <b> <c>, "2" .)
        nt = %(
          <a> <b> <c> .
          <a> <b> "2" .
        )
        expect(parse(ttl)).to be_equivalent_graph(nt, trace:  @debug)
      end
    end
    
    describe "predicateObjectList" do
      it "does that" do
        ttl = %(
        @prefix a: <http://foo/a#> .

        a:b a:p1 "123" ; a:p1 "456" .
        a:b a:p2 a:v1 ; a:p3 a:v2 .
        )
        nt = %(
        <http://foo/a#b> <http://foo/a#p1> "123" .
        <http://foo/a#b> <http://foo/a#p1> "456" .
        <http://foo/a#b> <http://foo/a#p2> <http://foo/a#v1> .
        <http://foo/a#b> <http://foo/a#p3> <http://foo/a#v2> .
        )
        expect(parse(ttl)).to be_equivalent_graph(nt, trace:  @debug)
      end
    end
    
    describe "collection" do
      it "empty list" do
        ttl = %(@prefix :<http://example.com/>. :empty :set ().)
        nt = %(
        <http://example.com/empty> <http://example.com/set> <http://www.w3.org/1999/02/22-rdf-syntax-ns#nil> .)
        expect(parse(ttl)).to be_equivalent_graph(nt, trace:  @debug)
      end
      
      it "single element" do
        ttl = %(@prefix :<http://example.com/>. :gregg :wrote ("RdfContext").)
        nt = %(
        _:bnode0 <http://www.w3.org/1999/02/22-rdf-syntax-ns#first> "RdfContext" .
        _:bnode0 <http://www.w3.org/1999/02/22-rdf-syntax-ns#rest> <http://www.w3.org/1999/02/22-rdf-syntax-ns#nil> .
        <http://example.com/gregg> <http://example.com/wrote> _:bnode0 .
        )
        expect(parse(ttl)).to be_equivalent_graph(nt, trace:  @debug)
      end
      
      it "multiple elements" do
        ttl = %(@prefix :<http://example.com/>. :gregg :name ("Gregg" "Barnum" "Kellogg").)
        nt = %(
        _:bnode0 <http://www.w3.org/1999/02/22-rdf-syntax-ns#first> "Gregg" .
        _:bnode0 <http://www.w3.org/1999/02/22-rdf-syntax-ns#rest> _:bnode1 .
        _:bnode1 <http://www.w3.org/1999/02/22-rdf-syntax-ns#first> "Barnum" .
        _:bnode1 <http://www.w3.org/1999/02/22-rdf-syntax-ns#rest> _:bnode2 .
        _:bnode2 <http://www.w3.org/1999/02/22-rdf-syntax-ns#first> "Kellogg" .
        _:bnode2 <http://www.w3.org/1999/02/22-rdf-syntax-ns#rest> <http://www.w3.org/1999/02/22-rdf-syntax-ns#nil> .
        <http://example.com/gregg> <http://example.com/name> _:bnode0 .
        )
        expect(parse(ttl)).to be_equivalent_graph(nt, trace:  @debug)
      end
      
      it "as subject" do
        ttl = %(
          ("1" "2" "3") .
          # This is not a statement.
          () .
        )
        nt = %(
          _:a <http://www.w3.org/1999/02/22-rdf-syntax-ns#first> "1" .
          _:a <http://www.w3.org/1999/02/22-rdf-syntax-ns#rest> _:b .
          _:b <http://www.w3.org/1999/02/22-rdf-syntax-ns#first> "2" .
          _:b <http://www.w3.org/1999/02/22-rdf-syntax-ns#rest> _:c .
          _:c <http://www.w3.org/1999/02/22-rdf-syntax-ns#first> "3" .
          _:c <http://www.w3.org/1999/02/22-rdf-syntax-ns#rest> <http://www.w3.org/1999/02/22-rdf-syntax-ns#nil> .
        )
        expect {parse(ttl, validate:  true)}.to raise_error(RDF::ReaderError)
        expect(parse(ttl, validate:  false)).to be_equivalent_graph(nt, trace:  @debug)
      end
      
      it "adds property to nil list" do
        ttl = %(@prefix a: <http://foo/a#> . () a:prop "nilProp" .)
        nt = %(<http://www.w3.org/1999/02/22-rdf-syntax-ns#nil> <http://foo/a#prop> "nilProp" .)
        expect(parse(ttl)).to be_equivalent_graph(nt, trace:  @debug)
      end

      it "compound items" do
        ttl = %(
          :a :p (
            [ :p2 "v1" ] 
            <http://resource1>
            <http://resource2>
            ("inner list")
            "value"
          ) .
        )
        nt = %(
          <a> <p> _:a .
          _:a <http://www.w3.org/1999/02/22-rdf-syntax-ns#first> _:b .
          _:b <p2> "v1" .
          _:a <http://www.w3.org/1999/02/22-rdf-syntax-ns#rest> _:c .
          _:c <http://www.w3.org/1999/02/22-rdf-syntax-ns#first> <http://resource1> .
          _:c <http://www.w3.org/1999/02/22-rdf-syntax-ns#rest> _:d .
          _:d <http://www.w3.org/1999/02/22-rdf-syntax-ns#first> <http://resource2> .
          _:d <http://www.w3.org/1999/02/22-rdf-syntax-ns#rest> _:e .
          _:e <http://www.w3.org/1999/02/22-rdf-syntax-ns#first> _:inner_list .
          _:e <http://www.w3.org/1999/02/22-rdf-syntax-ns#rest> _:f .
          _:inner_list <http://www.w3.org/1999/02/22-rdf-syntax-ns#first> "inner list" .
          _:inner_list <http://www.w3.org/1999/02/22-rdf-syntax-ns#rest> <http://www.w3.org/1999/02/22-rdf-syntax-ns#nil> .
          _:f <http://www.w3.org/1999/02/22-rdf-syntax-ns#first> "value" .
          _:f <http://www.w3.org/1999/02/22-rdf-syntax-ns#rest> <http://www.w3.org/1999/02/22-rdf-syntax-ns#nil> .
        )
        expect(parse(ttl, prefixes:  {nil => ''})).to be_equivalent_graph(nt, trace:  @debug)
      end
      
    end
  end

  describe "canonicalization" do
    {
      %("+1"^^xsd:integer)  => %("1"^^<http://www.w3.org/2001/XMLSchema#integer>),
      %(+1)                 => %("1"^^<http://www.w3.org/2001/XMLSchema#integer>),
      %(.1)                 => %("0.1"^^<http://www.w3.org/2001/XMLSchema#decimal>),
      %(123.E+1)            => %("123.0E1"^^<http://www.w3.org/2001/XMLSchema#double> .),
      %(true)               => %("true"^^<http://www.w3.org/2001/XMLSchema#boolean>),
      %("lang"@EN)          => %("lang"@en),
    }.each_pair do |input, result|
      it "returns object #{result} given #{input}" do
        ttl = %(@prefix xsd: <http://www.w3.org/2001/XMLSchema#> . <a> <b> #{input} .)
        nt = %(<a> <b> #{result} .)
        expect(parse(ttl, canonicalize:  true)).to be_equivalent_graph(nt, trace:  @debug)
      end
    end
  end

  describe "malformed datatypes" do
    {
      "xsd:boolean" => %w(foo),
      "xsd:date" => %w(+2010-01-01Z 2010-01-01TFOO 02010-01-01 2010-1-1 0000-01-01 2011-07 2011),
      "xsd:dateTime" => %w(+2010-01-01T00:00:00Z 2010-01-01T00:00:00FOO 02010-01-01T00:00:00 2010-01-01 2010-1-1T00:00:00 0000-01-01T00:00:00 2011-07 2011),
      "xsd:decimal" => %w(12.xyz),
      "xsd:double" => %w(xy.z +1.0z),
      "xsd:integer" => %w(+1.0z foo),
      "xsd:time" => %w(+00:00:00Z -00:00:00Z 00:00 00),
    }.each do |dt, values|
      context dt do
        values.each do |value|
          before(:all) do
            @input = %(
              @prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
              @prefix xsd: <http://www.w3.org/2001/XMLSchema#> .
              <> rdf:value "#{value}"^^#{dt} .
            )
            dt_uri = RDF::XSD.send(dt.split(':').last)
            @expected = RDF::Graph.new << RDF::Statement.new(RDF::URI(""), RDF.value, RDF::Literal.new(value, datatype:  dt_uri))
          end

          context "with #{value}" do
            it "creates triple with invalid literal" do
              expect(parse(@input, validate:  false)).to be_equivalent_graph(@expected, trace:  @debug)
            end
            
            it "does not create triple when validating" do
              expect {parse(@input, validate:  true)}.to raise_error(RDF::ReaderError)
            end
          end
        end
      end
    end
  end

  describe "validation" do
    {
      %(<a> <b> "xyz"^^<http://www.w3.org/2001/XMLSchema#integer> .) => %r("xyz" is not a valid .*),
      %(<a> <b> "12xyz"^^<http://www.w3.org/2001/XMLSchema#integer> .) => %r("12xyz" is not a valid .*),
      %(<a> <b> "xy.z"^^<http://www.w3.org/2001/XMLSchema#double> .) => %r("xy\.z" is not a valid .*),
      %(<a> <b> "+1.0z"^^<http://www.w3.org/2001/XMLSchema#double> .) => %r("\+1.0z" is not a valid .*),
      %(<a> <b> .) => RDF::ReaderError,
      %(<a> <b> <c>) => RDF::ReaderError,
      %(<a> <b> <c> ;) => RDF::ReaderError,
      %(<a> "literal value" <b> .) => RDF::ReaderError,
      %(@keywords prefix. :e prefix :f .) => RDF::ReaderError,
      %(@base) => RDF::ReaderError,
    }.each_pair do |ttl, error|
      it "should raise '#{error}' for '#{ttl}'" do
        expect {
          parse("@prefix xsd: <http://www.w3.org/2001/XMLSchema#> . #{ttl}", base_uri:  "http://a/b",
                validate:  true)
        }.to raise_error(error)
      end
    end
  end

  describe "recovery" do
    {
      "malformed bnode subject" => [
        %q(_:.1 <http://example/a> <http://example/b> . _:bn <http://example/a> <http://example/c> .),
        %q(_:bn <http://example/a> <http://example/c> .)
      ],
      "malformed bnode object(1)" => [
        %q(<http://example/a> <http://example/b> _:.1 . <http://example/a> <http://example/c> <http://example/d> .),
        %q(<http://example/a> <http://example/c> <http://example/d> .)
      ],
      "malformed bnode object(2)" => [
        %q(
          <http://example/a> <http://example/b> _:-a;
                             <http://example/c> <http://example/d> .
          <http://example/e> <http://example/f>  <http://example/g> .),
        %q(<http://example/e> <http://example/f>  <http://example/g> .)
      ],
      "malformed bnode object(3)" => [
        %q(<http://example/a> <http://example/b> _:-a, <http://example/d> .),
        %q(),
      ],
      "malformed uri subject" => [
        %q(<"quoted"> <http://example/a> <http://example/b> . <http://example/c> <http://example/d> <http://example/e> .),
        %q(<http://example/c> <http://example/d> <http://example/e> .)
      ],
      "malformed uri predicate(1)" => [
        %q(<http://example/a> <"quoted"> <http://example/b> . <http://example/c> <http://example/d> <http://example/e> .),
        %q(<http://example/c> <http://example/d> <http://example/e> .)
      ],
      "malformed uri predicate(2)" => [
        %q(<http://example/a> <"quoted"> <http://example/b>; <http://example/d> <http://example/e> .),
        %q()
      ],
      "malformed uri object(1)" => [
        %q(<http://example/a> <http://example/b> <"quoted"> . <http://example/c> <http://example/d> <http://example/e> .),
        %q(<http://example/c> <http://example/d> <http://example/e> .)
      ],
      "malformed uri object(2)" => [
        %q(<http://example/a> <http://example/b> <"quoted">; <http://example/d> <http://example/e> .),
        %q()
      ],
      "malformed uri object(freebase)" => [
        %q(
          <http://example/a> <http://example/b> <http://http:urbis.com> .
          <http://example/a> <http://example/b> <http://example/e> .
        ),
        %q(
          <http://example/a> <http://example/b> <http://http:urbis.com> .
          <http://example/a> <http://example/b> <http://example/e> .
        ),
        (RDF::VERSION.to_s < "1.1")
      ],
    }.each do |test, (input, expected, pending)|
      context test do
        it "raises an error if valiating" do
          expect {parse(input, validate:  true)}.to raise_error
        end
        
        it "continues after an error", pending:  pending do
          expect(parse(input, validate:  false)).to be_equivalent_graph(expected, trace:  @debug)
        end
      end
    end
  end
  
  describe "NTriples", skip: ENV["CI"] do
    subject {
      RDF::Graph.load("http://www.w3.org/2000/10/rdf-tests/rdfcore/ntriples/test.nt", format:  :ttl)
    }
    it "parses test file" do
      expect(subject.count).to eq 30
    end
  end 

  describe "Base IRI resolution" do
    # From https://gist.github.com/RubenVerborgh/39f0e8d63e33e435371a
    let(:ttl) {%q{
      # RFC3986 normal examples
      @base <http://a/bb/ccc/d;p?q>.
      <urn:s001> <urn:p> <g:h>.
      <urn:s002> <urn:p> <g>.
      <urn:s003> <urn:p> <./g>.
      <urn:s004> <urn:p> <g/>.
      <urn:s005> <urn:p> </g>.
      <urn:s006> <urn:p> <//g>.
      <urn:s007> <urn:p> <?y>.
      <urn:s008> <urn:p> <g?y>.
      <urn:s009> <urn:p> <#s>.
      <urn:s010> <urn:p> <g#s>.
      <urn:s011> <urn:p> <g?y#s>.
      <urn:s012> <urn:p> <;x>.
      <urn:s013> <urn:p> <g;x>.
      <urn:s014> <urn:p> <g;x?y#s>.
      <urn:s015> <urn:p> <>.
      <urn:s016> <urn:p> <.>.
      <urn:s017> <urn:p> <./>.
      <urn:s018> <urn:p> <..>.
      <urn:s019> <urn:p> <../>.
      <urn:s020> <urn:p> <../g>.
      <urn:s021> <urn:p> <../..>.
      <urn:s022> <urn:p> <../../>.
      <urn:s023> <urn:p> <../../g>.

      # RFC3986 abnormal examples
      @base <http://a/bb/ccc/d;p?q>.
      <urn:s024> <urn:p> <../../../g>.
      <urn:s025> <urn:p> <../../../../g>.
      <urn:s026> <urn:p> </./g>.
      <urn:s027> <urn:p> </../g>.
      <urn:s028> <urn:p> <g.>.
      <urn:s029> <urn:p> <.g>.
      <urn:s030> <urn:p> <g..>.
      <urn:s031> <urn:p> <..g>.
      <urn:s032> <urn:p> <./../g>.
      <urn:s033> <urn:p> <./g/.>.
      <urn:s034> <urn:p> <g/./h>.
      <urn:s035> <urn:p> <g/../h>.
      <urn:s036> <urn:p> <g;x=1/./y>.
      <urn:s037> <urn:p> <g;x=1/../y>.
      <urn:s038> <urn:p> <g?y/./x>.
      <urn:s039> <urn:p> <g?y/../x>.
      <urn:s040> <urn:p> <g#s/./x>.
      <urn:s041> <urn:p> <g#s/../x>.
      <urn:s042> <urn:p> <http:g>.

      # RFC3986 normal examples with trailing slash in base IRI
      @base <http://a/bb/ccc/d/>.
      <urn:s043> <urn:p> <g:h>.
      <urn:s044> <urn:p> <g>.
      <urn:s045> <urn:p> <./g>.
      <urn:s046> <urn:p> <g/>.
      <urn:s047> <urn:p> </g>.
      <urn:s048> <urn:p> <//g>.
      <urn:s049> <urn:p> <?y>.
      <urn:s050> <urn:p> <g?y>.
      <urn:s051> <urn:p> <#s>.
      <urn:s052> <urn:p> <g#s>.
      <urn:s053> <urn:p> <g?y#s>.
      <urn:s054> <urn:p> <;x>.
      <urn:s055> <urn:p> <g;x>.
      <urn:s056> <urn:p> <g;x?y#s>.
      <urn:s057> <urn:p> <>.
      <urn:s058> <urn:p> <.>.
      <urn:s059> <urn:p> <./>.
      <urn:s060> <urn:p> <..>.
      <urn:s061> <urn:p> <../>.
      <urn:s062> <urn:p> <../g>.
      <urn:s063> <urn:p> <../..>.
      <urn:s064> <urn:p> <../../>.
      <urn:s065> <urn:p> <../../g>.

      # RFC3986 abnormal examples with trailing slash in base IRI
      @base <http://a/bb/ccc/d/>.
      <urn:s066> <urn:p> <../../../g>.
      <urn:s067> <urn:p> <../../../../g>.
      <urn:s068> <urn:p> </./g>.
      <urn:s069> <urn:p> </../g>.
      <urn:s070> <urn:p> <g.>.
      <urn:s071> <urn:p> <.g>.
      <urn:s072> <urn:p> <g..>.
      <urn:s073> <urn:p> <..g>.
      <urn:s074> <urn:p> <./../g>.
      <urn:s075> <urn:p> <./g/.>.
      <urn:s076> <urn:p> <g/./h>.
      <urn:s077> <urn:p> <g/../h>.
      <urn:s078> <urn:p> <g;x=1/./y>.
      <urn:s079> <urn:p> <g;x=1/../y>.
      <urn:s080> <urn:p> <g?y/./x>.
      <urn:s081> <urn:p> <g?y/../x>.
      <urn:s082> <urn:p> <g#s/./x>.
      <urn:s083> <urn:p> <g#s/../x>.
      <urn:s084> <urn:p> <http:g>.

      # RFC3986 normal examples0 with ./ in the base IRI
      @base <http://a/bb/ccc/./d;p?q>.
      <urn:s085> <urn:p> <g:h>.
      <urn:s086> <urn:p> <g>.
      <urn:s087> <urn:p> <./g>.
      <urn:s088> <urn:p> <g/>.
      <urn:s089> <urn:p> </g>.
      <urn:s090> <urn:p> <//g>.
      <urn:s091> <urn:p> <?y>.
      <urn:s092> <urn:p> <g?y>.
      <urn:s093> <urn:p> <#s>.
      <urn:s094> <urn:p> <g#s>.
      <urn:s095> <urn:p> <g?y#s>.
      <urn:s096> <urn:p> <;x>.
      <urn:s097> <urn:p> <g;x>.
      <urn:s098> <urn:p> <g;x?y#s>.
      <urn:s099> <urn:p> <>.
      <urn:s100> <urn:p> <.>.
      <urn:s101> <urn:p> <./>.
      <urn:s102> <urn:p> <..>.
      <urn:s103> <urn:p> <../>.
      <urn:s104> <urn:p> <../g>.
      <urn:s105> <urn:p> <../..>.
      <urn:s106> <urn:p> <../../>.
      <urn:s107> <urn:p> <../../g>.

      # RFC3986 abnormal examples with ./ in the base IRI
      @base <http://a/bb/ccc/./d;p?q>.
      <urn:s108> <urn:p> <../../../g>.
      <urn:s109> <urn:p> <../../../../g>.
      <urn:s110> <urn:p> </./g>.
      <urn:s111> <urn:p> </../g>.
      <urn:s112> <urn:p> <g.>.
      <urn:s113> <urn:p> <.g>.
      <urn:s114> <urn:p> <g..>.
      <urn:s115> <urn:p> <..g>.
      <urn:s116> <urn:p> <./../g>.
      <urn:s117> <urn:p> <./g/.>.
      <urn:s118> <urn:p> <g/./h>.
      <urn:s119> <urn:p> <g/../h>.
      <urn:s120> <urn:p> <g;x=1/./y>.
      <urn:s121> <urn:p> <g;x=1/../y>.
      <urn:s122> <urn:p> <g?y/./x>.
      <urn:s123> <urn:p> <g?y/../x>.
      <urn:s124> <urn:p> <g#s/./x>.
      <urn:s125> <urn:p> <g#s/../x>.
      <urn:s126> <urn:p> <http:g>.

      # RFC3986 normal examples with ../ in the base IRI
      @base <http://a/bb/ccc/../d;p?q>.
      <urn:s127> <urn:p> <g:h>.
      <urn:s128> <urn:p> <g>.
      <urn:s129> <urn:p> <./g>.
      <urn:s130> <urn:p> <g/>.
      <urn:s131> <urn:p> </g>.
      <urn:s132> <urn:p> <//g>.
      <urn:s133> <urn:p> <?y>.
      <urn:s134> <urn:p> <g?y>.
      <urn:s135> <urn:p> <#s>.
      <urn:s136> <urn:p> <g#s>.
      <urn:s137> <urn:p> <g?y#s>.
      <urn:s138> <urn:p> <;x>.
      <urn:s139> <urn:p> <g;x>.
      <urn:s140> <urn:p> <g;x?y#s>.
      <urn:s141> <urn:p> <>.
      <urn:s142> <urn:p> <.>.
      <urn:s143> <urn:p> <./>.
      <urn:s144> <urn:p> <..>.
      <urn:s145> <urn:p> <../>.
      <urn:s146> <urn:p> <../g>.
      <urn:s147> <urn:p> <../..>.
      <urn:s148> <urn:p> <../../>.
      <urn:s149> <urn:p> <../../g>.

      # RFC3986 abnormal examples with ../ in the base IRI
      @base <http://a/bb/ccc/../d;p?q>.
      <urn:s150> <urn:p> <../../../g>.
      <urn:s151> <urn:p> <../../../../g>.
      <urn:s152> <urn:p> </./g>.
      <urn:s153> <urn:p> </../g>.
      <urn:s154> <urn:p> <g.>.
      <urn:s155> <urn:p> <.g>.
      <urn:s156> <urn:p> <g..>.
      <urn:s157> <urn:p> <..g>.
      <urn:s158> <urn:p> <./../g>.
      <urn:s159> <urn:p> <./g/.>.
      <urn:s160> <urn:p> <g/./h>.
      <urn:s161> <urn:p> <g/../h>.
      <urn:s162> <urn:p> <g;x=1/./y>.
      <urn:s163> <urn:p> <g;x=1/../y>.
      <urn:s164> <urn:p> <g?y/./x>.
      <urn:s165> <urn:p> <g?y/../x>.
      <urn:s166> <urn:p> <g#s/./x>.
      <urn:s167> <urn:p> <g#s/../x>.
      <urn:s168> <urn:p> <http:g>.

      # RFC3986 normal examples with trailing ./ in the base IRI
      @base <http://a/bb/ccc/.>.
      <urn:s169> <urn:p> <g:h>.
      <urn:s170> <urn:p> <g>.
      <urn:s171> <urn:p> <./g>.
      <urn:s172> <urn:p> <g/>.
      <urn:s173> <urn:p> </g>.
      <urn:s174> <urn:p> <//g>.
      <urn:s175> <urn:p> <?y>.
      <urn:s176> <urn:p> <g?y>.
      <urn:s177> <urn:p> <#s>.
      <urn:s178> <urn:p> <g#s>.
      <urn:s179> <urn:p> <g?y#s>.
      <urn:s180> <urn:p> <;x>.
      <urn:s181> <urn:p> <g;x>.
      <urn:s182> <urn:p> <g;x?y#s>.
      <urn:s183> <urn:p> <>.
      <urn:s184> <urn:p> <.>.
      <urn:s185> <urn:p> <./>.
      <urn:s186> <urn:p> <..>.
      <urn:s187> <urn:p> <../>.
      <urn:s188> <urn:p> <../g>.
      <urn:s189> <urn:p> <../..>.
      <urn:s190> <urn:p> <../../>.
      <urn:s191> <urn:p> <../../g>.

      # RFC3986 abnormal examples with trailing ./ in the base IRI
      @base <http://a/bb/ccc/.>.
      <urn:s192> <urn:p> <../../../g>.
      <urn:s193> <urn:p> <../../../../g>.
      <urn:s194> <urn:p> </./g>.
      <urn:s195> <urn:p> </../g>.
      <urn:s196> <urn:p> <g.>.
      <urn:s197> <urn:p> <.g>.
      <urn:s198> <urn:p> <g..>.
      <urn:s199> <urn:p> <..g>.
      <urn:s200> <urn:p> <./../g>.
      <urn:s201> <urn:p> <./g/.>.
      <urn:s202> <urn:p> <g/./h>.
      <urn:s203> <urn:p> <g/../h>.
      <urn:s204> <urn:p> <g;x=1/./y>.
      <urn:s205> <urn:p> <g;x=1/../y>.
      <urn:s206> <urn:p> <g?y/./x>.
      <urn:s207> <urn:p> <g?y/../x>.
      <urn:s208> <urn:p> <g#s/./x>.
      <urn:s209> <urn:p> <g#s/../x>.
      <urn:s210> <urn:p> <http:g>.

      # RFC3986 normal examples with trailing ../ in the base IRI
      @base <http://a/bb/ccc/..>.
      <urn:s211> <urn:p> <g:h>.
      <urn:s212> <urn:p> <g>.
      <urn:s213> <urn:p> <./g>.
      <urn:s214> <urn:p> <g/>.
      <urn:s215> <urn:p> </g>.
      <urn:s216> <urn:p> <//g>.
      <urn:s217> <urn:p> <?y>.
      <urn:s218> <urn:p> <g?y>.
      <urn:s219> <urn:p> <#s>.
      <urn:s220> <urn:p> <g#s>.
      <urn:s221> <urn:p> <g?y#s>.
      <urn:s222> <urn:p> <;x>.
      <urn:s223> <urn:p> <g;x>.
      <urn:s224> <urn:p> <g;x?y#s>.
      <urn:s225> <urn:p> <>.
      <urn:s226> <urn:p> <.>.
      <urn:s227> <urn:p> <./>.
      <urn:s228> <urn:p> <..>.
      <urn:s229> <urn:p> <../>.
      <urn:s230> <urn:p> <../g>.
      <urn:s231> <urn:p> <../..>.
      <urn:s232> <urn:p> <../../>.
      <urn:s233> <urn:p> <../../g>.

      # RFC3986 abnormal examples with trailing ../ in the base IRI
      @base <http://a/bb/ccc/..>.
      <urn:s234> <urn:p> <../../../g>.
      <urn:s235> <urn:p> <../../../../g>.
      <urn:s236> <urn:p> </./g>.
      <urn:s237> <urn:p> </../g>.
      <urn:s238> <urn:p> <g.>.
      <urn:s239> <urn:p> <.g>.
      <urn:s240> <urn:p> <g..>.
      <urn:s241> <urn:p> <..g>.
      <urn:s242> <urn:p> <./../g>.
      <urn:s243> <urn:p> <./g/.>.
      <urn:s244> <urn:p> <g/./h>.
      <urn:s245> <urn:p> <g/../h>.
      <urn:s246> <urn:p> <g;x=1/./y>.
      <urn:s247> <urn:p> <g;x=1/../y>.
      <urn:s248> <urn:p> <g?y/./x>.
      <urn:s249> <urn:p> <g?y/../x>.
      <urn:s250> <urn:p> <g#s/./x>.
      <urn:s251> <urn:p> <g#s/../x>.
      <urn:s252> <urn:p> <http:g>.

      # additional cases
      @base <http://abc/def/ghi>.
      <urn:s253> <urn:p> <.>.
      <urn:s254> <urn:p> <.?a=b>.
      <urn:s255> <urn:p> <.#a=b>.
      <urn:s256> <urn:p> <..>.
      <urn:s257> <urn:p> <..?a=b>.
      <urn:s258> <urn:p> <..#a=b>.
      @base <http://ab//de//ghi>.
      <urn:s259> <urn:p> <xyz>.
      <urn:s260> <urn:p> <./xyz>.
      <urn:s261> <urn:p> <../xyz>.
      @base <http://abc/d:f/ghi>.
      <urn:s262> <urn:p> <xyz>.
      <urn:s263> <urn:p> <./xyz>.
      <urn:s264> <urn:p> <../xyz>.
    }}
    let(:nt) {%q{
      # RFC3986 normal examples

      <urn:s001> <urn:p> <g:h>.
      <urn:s002> <urn:p> <http://a/bb/ccc/g>.
      <urn:s003> <urn:p> <http://a/bb/ccc/g>.
      <urn:s004> <urn:p> <http://a/bb/ccc/g/>.
      <urn:s005> <urn:p> <http://a/g>.
      <urn:s006> <urn:p> <http://g>.
      <urn:s007> <urn:p> <http://a/bb/ccc/d;p?y>.
      <urn:s008> <urn:p> <http://a/bb/ccc/g?y>.
      <urn:s009> <urn:p> <http://a/bb/ccc/d;p?q#s>.
      <urn:s010> <urn:p> <http://a/bb/ccc/g#s>.
      <urn:s011> <urn:p> <http://a/bb/ccc/g?y#s>.
      <urn:s012> <urn:p> <http://a/bb/ccc/;x>.
      <urn:s013> <urn:p> <http://a/bb/ccc/g;x>.
      <urn:s014> <urn:p> <http://a/bb/ccc/g;x?y#s>.
      <urn:s015> <urn:p> <http://a/bb/ccc/d;p?q>.
      <urn:s016> <urn:p> <http://a/bb/ccc/>.
      <urn:s017> <urn:p> <http://a/bb/ccc/>.
      <urn:s018> <urn:p> <http://a/bb/>.
      <urn:s019> <urn:p> <http://a/bb/>.
      <urn:s020> <urn:p> <http://a/bb/g>.
      <urn:s021> <urn:p> <http://a/>.
      <urn:s022> <urn:p> <http://a/>.
      <urn:s023> <urn:p> <http://a/g>.

      # RFC3986 abnormal examples

      <urn:s024> <urn:p> <http://a/g>.
      <urn:s025> <urn:p> <http://a/g>.
      <urn:s026> <urn:p> <http://a/g>.
      <urn:s027> <urn:p> <http://a/g>.
      <urn:s028> <urn:p> <http://a/bb/ccc/g.>.
      <urn:s029> <urn:p> <http://a/bb/ccc/.g>.
      <urn:s030> <urn:p> <http://a/bb/ccc/g..>.
      <urn:s031> <urn:p> <http://a/bb/ccc/..g>.
      <urn:s032> <urn:p> <http://a/bb/g>.
      <urn:s033> <urn:p> <http://a/bb/ccc/g/>.
      <urn:s034> <urn:p> <http://a/bb/ccc/g/h>.
      <urn:s035> <urn:p> <http://a/bb/ccc/h>.
      <urn:s036> <urn:p> <http://a/bb/ccc/g;x=1/y>.
      <urn:s037> <urn:p> <http://a/bb/ccc/y>.
      <urn:s038> <urn:p> <http://a/bb/ccc/g?y/./x>.
      <urn:s039> <urn:p> <http://a/bb/ccc/g?y/../x>.
      <urn:s040> <urn:p> <http://a/bb/ccc/g#s/./x>.
      <urn:s041> <urn:p> <http://a/bb/ccc/g#s/../x>.
      <urn:s042> <urn:p> <http:g>.

      # RFC3986 normal examples with trailing slash in base IRI

      <urn:s043> <urn:p> <g:h>.
      <urn:s044> <urn:p> <http://a/bb/ccc/d/g>.
      <urn:s045> <urn:p> <http://a/bb/ccc/d/g>.
      <urn:s046> <urn:p> <http://a/bb/ccc/d/g/>.
      <urn:s047> <urn:p> <http://a/g>.
      <urn:s048> <urn:p> <http://g>.
      <urn:s049> <urn:p> <http://a/bb/ccc/d/?y>.
      <urn:s050> <urn:p> <http://a/bb/ccc/d/g?y>.
      <urn:s051> <urn:p> <http://a/bb/ccc/d/#s>.
      <urn:s052> <urn:p> <http://a/bb/ccc/d/g#s>.
      <urn:s053> <urn:p> <http://a/bb/ccc/d/g?y#s>.
      <urn:s054> <urn:p> <http://a/bb/ccc/d/;x>.
      <urn:s055> <urn:p> <http://a/bb/ccc/d/g;x>.
      <urn:s056> <urn:p> <http://a/bb/ccc/d/g;x?y#s>.
      <urn:s057> <urn:p> <http://a/bb/ccc/d/>.
      <urn:s058> <urn:p> <http://a/bb/ccc/d/>.
      <urn:s059> <urn:p> <http://a/bb/ccc/d/>.
      <urn:s060> <urn:p> <http://a/bb/ccc/>.
      <urn:s061> <urn:p> <http://a/bb/ccc/>.
      <urn:s062> <urn:p> <http://a/bb/ccc/g>.
      <urn:s063> <urn:p> <http://a/bb/>.
      <urn:s064> <urn:p> <http://a/bb/>.
      <urn:s065> <urn:p> <http://a/bb/g>.

      # RFC3986 abnormal examples with trailing slash in base IRI

      <urn:s066> <urn:p> <http://a/g>.
      <urn:s067> <urn:p> <http://a/g>.
      <urn:s068> <urn:p> <http://a/g>.
      <urn:s069> <urn:p> <http://a/g>.
      <urn:s070> <urn:p> <http://a/bb/ccc/d/g.>.
      <urn:s071> <urn:p> <http://a/bb/ccc/d/.g>.
      <urn:s072> <urn:p> <http://a/bb/ccc/d/g..>.
      <urn:s073> <urn:p> <http://a/bb/ccc/d/..g>.
      <urn:s074> <urn:p> <http://a/bb/ccc/g>.
      <urn:s075> <urn:p> <http://a/bb/ccc/d/g/>.
      <urn:s076> <urn:p> <http://a/bb/ccc/d/g/h>.
      <urn:s077> <urn:p> <http://a/bb/ccc/d/h>.
      <urn:s078> <urn:p> <http://a/bb/ccc/d/g;x=1/y>.
      <urn:s079> <urn:p> <http://a/bb/ccc/d/y>.
      <urn:s080> <urn:p> <http://a/bb/ccc/d/g?y/./x>.
      <urn:s081> <urn:p> <http://a/bb/ccc/d/g?y/../x>.
      <urn:s082> <urn:p> <http://a/bb/ccc/d/g#s/./x>.
      <urn:s083> <urn:p> <http://a/bb/ccc/d/g#s/../x>.
      <urn:s084> <urn:p> <http:g>.

      # RFC3986 normal examples with ./ in the base IRI

      <urn:s085> <urn:p> <g:h>.
      <urn:s086> <urn:p> <http://a/bb/ccc/g>.
      <urn:s087> <urn:p> <http://a/bb/ccc/g>.
      <urn:s088> <urn:p> <http://a/bb/ccc/g/>.
      <urn:s089> <urn:p> <http://a/g>.
      <urn:s090> <urn:p> <http://g>.
      <urn:s091> <urn:p> <http://a/bb/ccc/./d;p?y>.
      <urn:s092> <urn:p> <http://a/bb/ccc/g?y>.
      <urn:s093> <urn:p> <http://a/bb/ccc/./d;p?q#s>.
      <urn:s094> <urn:p> <http://a/bb/ccc/g#s>.
      <urn:s095> <urn:p> <http://a/bb/ccc/g?y#s>.
      <urn:s096> <urn:p> <http://a/bb/ccc/;x>.
      <urn:s097> <urn:p> <http://a/bb/ccc/g;x>.
      <urn:s098> <urn:p> <http://a/bb/ccc/g;x?y#s>.
      <urn:s099> <urn:p> <http://a/bb/ccc/./d;p?q>.
      <urn:s100> <urn:p> <http://a/bb/ccc/>.
      <urn:s101> <urn:p> <http://a/bb/ccc/>.
      <urn:s102> <urn:p> <http://a/bb/>.
      <urn:s103> <urn:p> <http://a/bb/>.
      <urn:s104> <urn:p> <http://a/bb/g>.
      <urn:s105> <urn:p> <http://a/>.
      <urn:s106> <urn:p> <http://a/>.
      <urn:s107> <urn:p> <http://a/g>.

      # RFC3986 abnormal examples with ./ in the base IRI

      <urn:s108> <urn:p> <http://a/g>.
      <urn:s109> <urn:p> <http://a/g>.
      <urn:s110> <urn:p> <http://a/g>.
      <urn:s111> <urn:p> <http://a/g>.
      <urn:s112> <urn:p> <http://a/bb/ccc/g.>.
      <urn:s113> <urn:p> <http://a/bb/ccc/.g>.
      <urn:s114> <urn:p> <http://a/bb/ccc/g..>.
      <urn:s115> <urn:p> <http://a/bb/ccc/..g>.
      <urn:s116> <urn:p> <http://a/bb/g>.
      <urn:s117> <urn:p> <http://a/bb/ccc/g/>.
      <urn:s118> <urn:p> <http://a/bb/ccc/g/h>.
      <urn:s119> <urn:p> <http://a/bb/ccc/h>.
      <urn:s120> <urn:p> <http://a/bb/ccc/g;x=1/y>.
      <urn:s121> <urn:p> <http://a/bb/ccc/y>.
      <urn:s122> <urn:p> <http://a/bb/ccc/g?y/./x>.
      <urn:s123> <urn:p> <http://a/bb/ccc/g?y/../x>.
      <urn:s124> <urn:p> <http://a/bb/ccc/g#s/./x>.
      <urn:s125> <urn:p> <http://a/bb/ccc/g#s/../x>.
      <urn:s126> <urn:p> <http:g>.

      # RFC3986 normal examples with ../ in the base IRI

      <urn:s127> <urn:p> <g:h>.
      <urn:s128> <urn:p> <http://a/bb/g>.
      <urn:s129> <urn:p> <http://a/bb/g>.
      <urn:s130> <urn:p> <http://a/bb/g/>.
      <urn:s131> <urn:p> <http://a/g>.
      <urn:s132> <urn:p> <http://g>.
      <urn:s133> <urn:p> <http://a/bb/ccc/../d;p?y>.
      <urn:s134> <urn:p> <http://a/bb/g?y>.
      <urn:s135> <urn:p> <http://a/bb/ccc/../d;p?q#s>.
      <urn:s136> <urn:p> <http://a/bb/g#s>.
      <urn:s137> <urn:p> <http://a/bb/g?y#s>.
      <urn:s138> <urn:p> <http://a/bb/;x>.
      <urn:s139> <urn:p> <http://a/bb/g;x>.
      <urn:s140> <urn:p> <http://a/bb/g;x?y#s>.
      <urn:s141> <urn:p> <http://a/bb/ccc/../d;p?q>.
      <urn:s142> <urn:p> <http://a/bb/>.
      <urn:s143> <urn:p> <http://a/bb/>.
      <urn:s144> <urn:p> <http://a/>.
      <urn:s145> <urn:p> <http://a/>.
      <urn:s146> <urn:p> <http://a/g>.
      <urn:s147> <urn:p> <http://a/>.
      <urn:s148> <urn:p> <http://a/>.
      <urn:s149> <urn:p> <http://a/g>.

      # RFC3986 abnormal examples with ../ in the base IRI

      <urn:s150> <urn:p> <http://a/g>.
      <urn:s151> <urn:p> <http://a/g>.
      <urn:s152> <urn:p> <http://a/g>.
      <urn:s153> <urn:p> <http://a/g>.
      <urn:s154> <urn:p> <http://a/bb/g.>.
      <urn:s155> <urn:p> <http://a/bb/.g>.
      <urn:s156> <urn:p> <http://a/bb/g..>.
      <urn:s157> <urn:p> <http://a/bb/..g>.
      <urn:s158> <urn:p> <http://a/g>.
      <urn:s159> <urn:p> <http://a/bb/g/>.
      <urn:s160> <urn:p> <http://a/bb/g/h>.
      <urn:s161> <urn:p> <http://a/bb/h>.
      <urn:s162> <urn:p> <http://a/bb/g;x=1/y>.
      <urn:s163> <urn:p> <http://a/bb/y>.
      <urn:s164> <urn:p> <http://a/bb/g?y/./x>.
      <urn:s165> <urn:p> <http://a/bb/g?y/../x>.
      <urn:s166> <urn:p> <http://a/bb/g#s/./x>.
      <urn:s167> <urn:p> <http://a/bb/g#s/../x>.
      <urn:s168> <urn:p> <http:g>.

      # RFC3986 normal examples with trailing ./ in the base IRI

      <urn:s169> <urn:p> <g:h>.
      <urn:s170> <urn:p> <http://a/bb/ccc/g>.
      <urn:s171> <urn:p> <http://a/bb/ccc/g>.
      <urn:s172> <urn:p> <http://a/bb/ccc/g/>.
      <urn:s173> <urn:p> <http://a/g>.
      <urn:s174> <urn:p> <http://g>.
      <urn:s175> <urn:p> <http://a/bb/ccc/.?y>.
      <urn:s176> <urn:p> <http://a/bb/ccc/g?y>.
      <urn:s177> <urn:p> <http://a/bb/ccc/.#s>.
      <urn:s178> <urn:p> <http://a/bb/ccc/g#s>.
      <urn:s179> <urn:p> <http://a/bb/ccc/g?y#s>.
      <urn:s180> <urn:p> <http://a/bb/ccc/;x>.
      <urn:s181> <urn:p> <http://a/bb/ccc/g;x>.
      <urn:s182> <urn:p> <http://a/bb/ccc/g;x?y#s>.
      <urn:s183> <urn:p> <http://a/bb/ccc/.>.
      <urn:s184> <urn:p> <http://a/bb/ccc/>.
      <urn:s185> <urn:p> <http://a/bb/ccc/>.
      <urn:s186> <urn:p> <http://a/bb/>.
      <urn:s187> <urn:p> <http://a/bb/>.
      <urn:s188> <urn:p> <http://a/bb/g>.
      <urn:s189> <urn:p> <http://a/>.
      <urn:s190> <urn:p> <http://a/>.
      <urn:s191> <urn:p> <http://a/g>.

      # RFC3986 abnormal examples with trailing ./ in the base IRI

      <urn:s192> <urn:p> <http://a/g>.
      <urn:s193> <urn:p> <http://a/g>.
      <urn:s194> <urn:p> <http://a/g>.
      <urn:s195> <urn:p> <http://a/g>.
      <urn:s196> <urn:p> <http://a/bb/ccc/g.>.
      <urn:s197> <urn:p> <http://a/bb/ccc/.g>.
      <urn:s198> <urn:p> <http://a/bb/ccc/g..>.
      <urn:s199> <urn:p> <http://a/bb/ccc/..g>.
      <urn:s200> <urn:p> <http://a/bb/g>.
      <urn:s201> <urn:p> <http://a/bb/ccc/g/>.
      <urn:s202> <urn:p> <http://a/bb/ccc/g/h>.
      <urn:s203> <urn:p> <http://a/bb/ccc/h>.
      <urn:s204> <urn:p> <http://a/bb/ccc/g;x=1/y>.
      <urn:s205> <urn:p> <http://a/bb/ccc/y>.
      <urn:s206> <urn:p> <http://a/bb/ccc/g?y/./x>.
      <urn:s207> <urn:p> <http://a/bb/ccc/g?y/../x>.
      <urn:s208> <urn:p> <http://a/bb/ccc/g#s/./x>.
      <urn:s209> <urn:p> <http://a/bb/ccc/g#s/../x>.
      <urn:s210> <urn:p> <http:g>.

      # RFC3986 normal examples with trailing ../ in the base IRI

      <urn:s211> <urn:p> <g:h>.
      <urn:s212> <urn:p> <http://a/bb/ccc/g>.
      <urn:s213> <urn:p> <http://a/bb/ccc/g>.
      <urn:s214> <urn:p> <http://a/bb/ccc/g/>.
      <urn:s215> <urn:p> <http://a/g>.
      <urn:s216> <urn:p> <http://g>.
      <urn:s217> <urn:p> <http://a/bb/ccc/..?y>.
      <urn:s218> <urn:p> <http://a/bb/ccc/g?y>.
      <urn:s219> <urn:p> <http://a/bb/ccc/..#s>.
      <urn:s220> <urn:p> <http://a/bb/ccc/g#s>.
      <urn:s221> <urn:p> <http://a/bb/ccc/g?y#s>.
      <urn:s222> <urn:p> <http://a/bb/ccc/;x>.
      <urn:s223> <urn:p> <http://a/bb/ccc/g;x>.
      <urn:s224> <urn:p> <http://a/bb/ccc/g;x?y#s>.
      <urn:s225> <urn:p> <http://a/bb/ccc/..>.
      <urn:s226> <urn:p> <http://a/bb/ccc/>.
      <urn:s227> <urn:p> <http://a/bb/ccc/>.
      <urn:s228> <urn:p> <http://a/bb/>.
      <urn:s229> <urn:p> <http://a/bb/>.
      <urn:s230> <urn:p> <http://a/bb/g>.
      <urn:s231> <urn:p> <http://a/>.
      <urn:s232> <urn:p> <http://a/>.
      <urn:s233> <urn:p> <http://a/g>.

      # RFC3986 abnormal examples with trailing ../ in the base IRI

      <urn:s234> <urn:p> <http://a/g>.
      <urn:s235> <urn:p> <http://a/g>.
      <urn:s236> <urn:p> <http://a/g>.
      <urn:s237> <urn:p> <http://a/g>.
      <urn:s238> <urn:p> <http://a/bb/ccc/g.>.
      <urn:s239> <urn:p> <http://a/bb/ccc/.g>.
      <urn:s240> <urn:p> <http://a/bb/ccc/g..>.
      <urn:s241> <urn:p> <http://a/bb/ccc/..g>.
      <urn:s242> <urn:p> <http://a/bb/g>.
      <urn:s243> <urn:p> <http://a/bb/ccc/g/>.
      <urn:s244> <urn:p> <http://a/bb/ccc/g/h>.
      <urn:s245> <urn:p> <http://a/bb/ccc/h>.
      <urn:s246> <urn:p> <http://a/bb/ccc/g;x=1/y>.
      <urn:s247> <urn:p> <http://a/bb/ccc/y>.
      <urn:s248> <urn:p> <http://a/bb/ccc/g?y/./x>.
      <urn:s249> <urn:p> <http://a/bb/ccc/g?y/../x>.
      <urn:s250> <urn:p> <http://a/bb/ccc/g#s/./x>.
      <urn:s251> <urn:p> <http://a/bb/ccc/g#s/../x>.
      <urn:s252> <urn:p> <http:g>.

      # additional cases

      <urn:s253> <urn:p> <http://abc/def/>.
      <urn:s254> <urn:p> <http://abc/def/?a=b>.
      <urn:s255> <urn:p> <http://abc/def/#a=b>.
      <urn:s256> <urn:p> <http://abc/>.
      <urn:s257> <urn:p> <http://abc/?a=b>.
      <urn:s258> <urn:p> <http://abc/#a=b>.

      <urn:s259> <urn:p> <http://ab//de//xyz>.
      <urn:s260> <urn:p> <http://ab//de//xyz>.
      <urn:s261> <urn:p> <http://ab//de/xyz>.

      <urn:s262> <urn:p> <http://abc/d:f/xyz>.
      <urn:s263> <urn:p> <http://abc/d:f/xyz>.
      <urn:s264> <urn:p> <http://abc/xyz>.
    }}
    it "produces equivalent triples" do
      nt_str = RDF::NTriples::Reader.new(nt).dump(:ntriples)
      ttl_str = RDF::Turtle::Reader.new(ttl).dump(:ntriples)
      expect(ttl_str).to eql(nt_str)
    end
  end

  describe "spec examples" do
    {
      "example 1" => [
        %q(
          @prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
          @prefix dc: <http://purl.org/dc/elements/1.1/> .
          @prefix ex: <http://example/stuff/1.0/> .

          <http://www.w3.org/TR/rdf-syntax-grammar>
            dc:title "RDF/XML Syntax Specification (Revised)" ;
            ex:editor [
              ex:fullname "Dave Beckett";
              ex:homePage <http://purl.org/net/dajobe/>
            ] .
        ),
        %q(
          @prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
          @prefix dc: <http://purl.org/dc/elements/1.1/> .
          @prefix ex: <http://example/stuff/1.0/> .

          <http://www.w3.org/TR/rdf-syntax-grammar>
            dc:title "RDF/XML Syntax Specification (Revised)";
            ex:editor _:a .
          _:a ex:fullname "Dave Beckett";
            ex:homePage <http://purl.org/net/dajobe/> .
        )
      ],
      "example 2" => [
        %q(
          @prefix : <http://example/stuff/1.0/> .
          <a> :b ( "apple" "banana" ) .
        ),
        %q(
          @prefix : <http://example/stuff/1.0/> .
          @prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
          <a> :b
            [ rdf:first "apple";
              rdf:rest [ rdf:first "banana";
                         rdf:rest rdf:nil ]
            ] .
        )
      ],
      "example 3" => [
        %q(
          @prefix : <http://example/stuff/1.0/> .

          :a :b "The first line\nThe second line\n  more" .

          :a :b """The first line
The second line
  more""" .
        ),
        %q(
        <http://example/stuff/1.0/a> <http://example/stuff/1.0/b>
        "The first line\nThe second line\n  more" .
        )
      ],
      # Spec confusion: default prefix must be defined
      "example 4" => [
        %q((1 2.0 3E1) :p "w" .),
        %q(
          @prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
          _:b0  rdf:first  1 ;
                rdf:rest   _:b1 .
          _:b1  rdf:first  2.0 ;
                rdf:rest   _:b2 .
          _:b2  rdf:first  3E1 ;
                rdf:rest   rdf:nil .
          _:b0  :p         "w" . 
        )
      ],
      # Spec confusion: Can list be subject w/o object?
      "example 5" => [
        %q(@prefix : <> . (1 [:p :q] ( 2 ) ) .),
        %q(
          @prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
          @prefix : <> . 
          _:b0  rdf:first  1 ;
                rdf:rest   _:b1 .
          _:b1  rdf:first  _:b2 .
          _:b2  :p         :q .
          _:b1  rdf:rest   _:b3 .
          _:b3  rdf:first  _:b4 .
          _:b4  rdf:first  2 ;
                rdf:rest   rdf:nil .
          _:b3  rdf:rest   rdf:nil .
        )
      ],
      "bbc short" => [
        %q(
          @prefix po: <http://purl.org/ontology/po/>.
          _:a a _:b; .
          _:c a _:d; .
        ),
        %q(
          _:a <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> _:b .
          _:c <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> _:d .
        )
      ],
      "bbc programmes" => [
        %q(
          @prefix dc: <http://purl.org/dc/elements/1.1/>.
          @prefix po: <http://purl.org/ontology/po/>.
          @prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>.
          _:broadcast
           a po:Broadcast;
           po:schedule_date """2008-06-24T12:00:00Z""";
           po:broadcast_of _:version;
           po:broadcast_on <http://www.bbc.co.uk/programmes/service/6music>;
          .
          _:version
           a po:Version;
          .
          <http://www.bbc.co.uk/programmes/b0072l93>
           dc:title """Nemone""";
           a po:Brand;
          .
          <http://www.bbc.co.uk/programmes/b00c735d>
           a po:Episode;
           po:episode <http://www.bbc.co.uk/programmes/b0072l93>;
           po:version _:version;
           po:long_synopsis """Actor and comedian Rhys Darby chats to Nemone.""";
           dc:title """Nemone""";
           po:synopsis """Actor and comedian Rhys Darby chats to Nemone.""";
          .
          <http://www.bbc.co.uk/programmes/service/6music>
           a po:Service;
           dc:title """BBC 6 Music""";
          .

          #_:abcd a po:Episode.
        ),
        %q(
          _:broadcast <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> <http://purl.org/ontology/po/Broadcast> .
          _:broadcast <http://purl.org/ontology/po/schedule_date> "2008-06-24T12:00:00Z" .
          _:broadcast <http://purl.org/ontology/po/broadcast_of> _:version .
          _:broadcast <http://purl.org/ontology/po/broadcast_on> <http://www.bbc.co.uk/programmes/service/6music> .
          _:version <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> <http://purl.org/ontology/po/Version> .
          <http://www.bbc.co.uk/programmes/b0072l93> <http://purl.org/dc/elements/1.1/title> "Nemone" .
          <http://www.bbc.co.uk/programmes/b0072l93> <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> <http://purl.org/ontology/po/Brand> .
          <http://www.bbc.co.uk/programmes/b00c735d> <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> <http://purl.org/ontology/po/Episode> .
          <http://www.bbc.co.uk/programmes/b00c735d> <http://purl.org/ontology/po/episode> <http://www.bbc.co.uk/programmes/b0072l93> .
          <http://www.bbc.co.uk/programmes/b00c735d> <http://purl.org/ontology/po/version> _:version .
          <http://www.bbc.co.uk/programmes/b00c735d> <http://purl.org/ontology/po/long_synopsis> "Actor and comedian Rhys Darby chats to Nemone." .
          <http://www.bbc.co.uk/programmes/b00c735d> <http://purl.org/dc/elements/1.1/title> "Nemone" .
          <http://www.bbc.co.uk/programmes/b00c735d> <http://purl.org/ontology/po/synopsis> "Actor and comedian Rhys Darby chats to Nemone." .
          <http://www.bbc.co.uk/programmes/service/6music> <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> <http://purl.org/ontology/po/Service> .
          <http://www.bbc.co.uk/programmes/service/6music> <http://purl.org/dc/elements/1.1/title> "BBC 6 Music" .
        )        
      ]
    }.each do |name, (input, expected)|
      it "matches Turtle spec #{name}" do
        begin
          g2 = parse(expected)
          g1 = parse(input)
          expect(g1).to be_equivalent_graph(g2, trace:  @debug)
        rescue RDF::ReaderError
          pending("Spec example fixes") if ["example 4", "example 5"].include?(name)
        end
      end
    end
  end

  def parse(input, options = {})
    @debug = []
    options = {
      debug:  @debug,
      validate:  false,
      canonicalize:  false,
    }.merge(options)
    graph = options[:graph] || RDF::Graph.new
    RDF::Turtle::Reader.new(input, options).each do |statement|
      graph << statement
    end
    graph
  end
end
