# coding: utf-8
$:.unshift "."
require 'spec_helper'
require 'rdf/spec/reader'

describe RDF::Turtle::Reader do
  let!(:doap) {File.expand_path("../../etc/doap.ttl", __FILE__)}
  let!(:doap_nt) {File.expand_path("../../etc/doap.nt", __FILE__)}
  let!(:doap_count) {File.open(doap_nt).each_line.to_a.length}
  after(:each) {|example| puts @logger.to_s if example.exception}

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
    context "with base_uri" do
      let(:base_uri) {"http://example.com/base/"}
      it "detects undefined nil prefix" do
        expect do
          r = RDF::Turtle::Reader.new(":a :b :c .", base_uri: base_uri, validate: true)
          r.each {|statement|}
        end.to raise_error RDF::ReaderError
      end

      it "detects undefined nil prefix with other prefixes defined" do
        expect do
          r = RDF::Turtle::Reader.new(":a rdf:type :c .", base_uri: base_uri, validate: true, prefixes: {rdf: "http://www.w3.org/1999/02/22-rdf-syntax-ns#"})
          r.each {|statement|}
        end.to raise_error RDF::ReaderError
      end
    end

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
          graph = parse(triple, validate: false, prefixes:  {nil => ''})
          statement = graph.statements.to_a.first
          expect(graph.size).to eq 1
          expect(statement.object.value).to eq contents
        end
      end
      
      # Rubinius problem with UTF-8 indexing:
      # "\"D\xC3\xBCrst\""[1..-2] => "D\xC3\xBCrst\""
      {
        'Dürst' => '<a> <b> "Dürst" .',
        'Dürster' => '<a> <b> <Dürster> .',
        "é" => '<a> <b>  "é" .',
        "€" => '<a> <b>  "€" .',
        "resumé" => ':a :resume  "resumé" .',
      }.each_pair do |contents, triple|
        specify "test #{triple}" do
          graph = parse(triple, validate: false, prefixes:  {nil => ''})
          statement = graph.statements.to_a.first
          expect(graph.size).to eq 1
          expect(statement.object.value).to eq contents
        end
      end
      
      it "should parse long literal with escape" do
        ttl = %(@prefix : <http://example/foo#> . <a> <b> """\\U00015678another""" .)
        statement = parse(ttl, validate: false).statements.to_a.first
        expect(statement.object.value).to eq "\u{15678}another"
      end
      
      context "STRING_LITERAL_LONG_QUOTE" do
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
          )
        }.each do |test, string|
          it "parses LONG1 #{test}" do
            graph = parse(%(<a> <b> '''#{string}'''.), validate: false)
            expect(graph.size).to eq 1
            expect(graph.statements.to_a.first.object.value).to eq string
          end

          it "parses LONG2 #{test}" do
            graph = parse(%(<a> <b> """#{string}""".), validate: false)
            expect(graph.size).to eq 1
            expect(graph.statements.to_a.first.object.value).to eq string
          end
        end
      end
      
      it "LONG1 matches trailing escaped single-quote" do
        graph = parse(%(<a> <b> '''\\''''.), validate: false)
        expect(graph.size).to eq 1
        expect(graph.statements.to_a.first.object.value).to eq %q(')
      end
      
      it "LONG2 matches trailing escaped double-quote" do
        graph = parse(%(<a> <b> """\\"""".), validate: false)
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
      statement = parse(ttl, validate: false, prefixes:  {nil => ''}).statements.to_a.first
      expect(statement.object.to_ntriples).to eq %("xyz"@en)
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
          expect(parse(ttl, validate:  true)).to be_equivalent_graph(nt, logger: @logger)
        end
      end

      {
        %(<http://example/#Dürst> <http://example/knows> <http://example/jane>.) => '<http://example/#D\u00FCrst> <http://example/knows> <http://example/jane> .',
        %(<http://example/Dürst> <http://example/knows> <http://example/jane>.) => '<http://example/D\u00FCrst> <http://example/knows> <http://example/jane> .',
        %(<http://example/bob> <http://example/resumé> "Bob's non-normalized resumé".) => '<http://example/bob> <http://example/resumé> "Bob\'s non-normalized resumé" .',
        %(<http://example/alice> <http://example/resumé> "Alice's normalized resumé".) => '<http://example/alice> <http://example/resumé> "Alice\'s normalized resumé" .',
        }.each_pair do |ttl, nt|
          it "for '#{ttl}'" do
            expect(parse(ttl)).to be_equivalent_graph(nt, logger: @logger)
          end
        end

      {
        %(<#Dürst> a  "URI straight in UTF8".) => %(<#D\\u00FCrst> <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> "URI straight in UTF8" .),
        %(<a> :related :ひらがな .) => %(<a> <related> <\\u3072\\u3089\\u304C\\u306A> .),
      }.each_pair do |ttl, nt|
        it "for '#{ttl}'" do
          expect(parse(ttl, validate: false, prefixes:  {nil => ''})).to be_equivalent_graph(nt, logger: @logger)
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
          expect {parse(%(<http://example/s> <http://example/p> <#{uri}>), validate:  true)}.to raise_error RDF::ReaderError
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
        expect(parse(ttl)).to be_equivalent_graph(nt, logger: @logger)
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
        %(<a> <b> 1.0E1 .)  => %(<a> <b> "1.0E1"^^<http://www.w3.org/2001/XMLSchema#double> .),
        %(<a> <b> 123.E+1 .)  => %(<a> <b> "123.0E+1"^^<http://www.w3.org/2001/XMLSchema#double> .),
      }.each_pair do |ttl, nt|
        it "should create typed literal for '#{ttl}'" do
          expect(parse(ttl, validate: false)).to be_equivalent_graph(nt, logger: @logger)
        end
      end
      
      it "should accept empty localname" do
        ttl1 = %(@prefix : <> .: : : .)
        ttl2 = %(<> <> <> .)
        g2 = parse(ttl2, validate: false)
        expect(parse(ttl1, validate: false)).to be_equivalent_graph(g2, logger: @logger)
      end
      
      it "should accept prefix with empty local name" do
        ttl = %(@prefix foo: <http://foo/bar#> . foo: foo: foo: .)
        nt = %(<http://foo/bar#> <http://foo/bar#> <http://foo/bar#> .)
        expect(parse(ttl, validate: false)).to be_equivalent_graph(nt, logger: @logger)
      end
    end
    
    describe "@prefix" do
      it "raises an error when validating if not defined" do
        ttl = %(<a> a :a .)
        expect {parse(ttl, validate:  true)}.to raise_error(RDF::ReaderError)
      end
      
      it "allows undefined empty prefix if not validating" do
        ttl = %(:a :b :c .)
        nt = %(<a> <b> <c> .)
        expect(parse(":a :b :c", validate:  false)).to be_equivalent_graph(nt, logger: @logger)
      end

      it "empty relative-IRI" do
        ttl = %(@prefix foo: <> . <a> a foo:a.)
        nt = %(<a> <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> <a> .)
        expect(parse(ttl, validate: false)).to be_equivalent_graph(nt, logger: @logger)
      end

      it "<#> as a prefix and as a triple node" do
        ttl = %(@prefix : <#> . <#> a :a.)
        nt = %(
        <#> <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> <#a> .
        )
        expect(parse(ttl, validate: false)).to be_equivalent_graph(nt, logger: @logger)
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
        expect(parse(ttl, validate:  false)).to be_equivalent_graph(nt, logger: @logger)
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
        expect(parse(ttl)).to be_equivalent_graph(nt, logger: @logger)
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
        "@prefix foo: <http://foo/bar#> ." => [true, true],
        "@PrEfIx foo: <http://foo/bar#> ." => [false, true],
        "prefix foo: <http://foo/bar#> ." => [false, true],
        "PrEfIx foo: <http://foo/bar#> ." => [false, true],
        "@prefix foo: <http://foo/bar#>" => [false, false],
        "@PrEfIx foo: <http://foo/bar#>" => [false, false],
        "prefix foo: <http://foo/bar#>" => [true, true],
        "PrEfIx foo: <http://foo/bar#>" => [true, true],
      }.each do |prefix, (valid, continues)|
        context prefix do
          it "sets prefix", pending: !continues do
            ttl = %(#{prefix} <http://example/a> a foo:a.)
            nt = %(<http://example/a> <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> <http://foo/bar#a> .)
            expect(parse(ttl, validate: false)).to be_equivalent_graph(nt, logger: @logger)
          end

          specify do
            ttl = %(#{prefix} <http://example/> a foo:a.)
            if valid
              expect {parse(ttl, validate:  true)}.not_to raise_error
            else
              expect {parse(ttl, validate:  true)}.to raise_error(RDF::ReaderError)
            end
          end
        end
      end
    end

    describe "@base" do
      {
        "absolute base" => [
          %(@base <http://foo/bar> . <> <a> <b> . <#c> <d> </e>.),
          %(
            <http://foo/bar> <http://foo/a> <http://foo/b> .
            <http://foo/bar#c> <http://foo/d> <http://foo/e> .
          )
        ],
        "absolute base (trailing /)" => [
          %(@base <http://foo/bar/> . <> <a> <b> . <#c> <d> </e>.),
          %(
            <http://foo/bar/> <http://foo/bar/a> <http://foo/bar/b> .
            <http://foo/bar/#c> <http://foo/bar/d> <http://foo/e> .
          )
        ],
        "absolute base (trailing #)" => [
          %(@base <http://foo/bar#> . <> <a> <b> . <#c> <d> </e>.),
          %(
            <http://foo/bar#> <http://foo/a> <http://foo/b> .
            <http://foo/bar#c> <http://foo/d> <http://foo/e> .
          )
        ],
        "relative base" => [
          %(
            @base <http://example/products/>.
            <> <a> <b>, <#c>.
            @base <prod123/>.
            <> <a> <b>, <#c>.
            @base <../>.
            <> <a> <d>, <#e>.
          ),
          %(
            <http://example/products/> <http://example/products/a> <http://example/products/b> .
            <http://example/products/> <http://example/products/a> <http://example/products/#c> .
            <http://example/products/prod123/> <http://example/products/prod123/a> <http://example/products/prod123/b> .
            <http://example/products/prod123/> <http://example/products/prod123/a> <http://example/products/prod123/#c> .
            <http://example/products/> <http://example/products/a> <http://example/products/d> .
            <http://example/products/> <http://example/products/a> <http://example/products/#e> .
          )
        ],
        "redefine" => [
          %(
            @base <http://example.com/ontolgies>. <a> <b> <foo/bar#baz>.
            @base <path/DIFFERENT/>. <a2> <b2> <foo/bar#baz2>.
            @prefix : <#>. <d3> :b3 <e3>.
          ),
          %(
            <http://example.com/a> <http://example.com/b> <http://example.com/foo/bar#baz> .
            <http://example.com/path/DIFFERENT/a2> <http://example.com/path/DIFFERENT/b2> <http://example.com/path/DIFFERENT/foo/bar#baz2> .
            <http://example.com/path/DIFFERENT/d3> <http://example.com/path/DIFFERENT/#b3> <http://example.com/path/DIFFERENT/e3> .
          )
        ],
      }.each do |name, (ttl, nt)|
        it name do
          expect(parse(ttl)).to be_equivalent_graph(nt, logger: @logger)
        end
      end

      {
        "@base <http://foo/bar> ." => [true, true],
        "@BaSe <http://foo/bar> ." => [false, true],
        "base <http://foo/bar> ." => [false, true],
        "BaSe <http://foo/bar> ." => [false, true],
        "@base <http://foo/bar>" => [false, false],
        "@BaSe <http://foo/bar>" => [false, false],
        "base <http://foo/bar>" => [true, true],
        "BaSe <http://foo/bar>" => [true, true],
      }.each do |base, (valid, continues)|
        context base do
          it "sets base", pending: !continues do
            ttl = %(#{base} <> <a> <b> . <#c> <d> </e>.)
            nt = %(
            <http://foo/bar> <http://foo/a> <http://foo/b> .
            <http://foo/bar#c> <http://foo/d> <http://foo/e> .
            )
            expect(parse(ttl, validate: false)).to be_equivalent_graph(nt, logger: @logger)
          end

          if valid
            specify do
              ttl = %(#{base} <> <a> <b> . <#c> <d> </e>.)
              expect {parse(ttl, validate:  true)}.not_to raise_error
            end
          else
            specify do
              ttl = %(#{base} <> <a> <b> . <#c> <d> </e>.)
              expect {parse(ttl, validate:  true)}.to raise_error(RDF::ReaderError)
            end
          end
        end
      end
    end
    
    describe "BNodes" do
      it "should create BNode for identifier with '_' prefix" do
        ttl = %(@prefix a: <http://foo/a#> . _:a a:p a:v .)
        nt = %(_:bnode0 <http://foo/a#p> <http://foo/a#v> .)
        expect(parse(ttl)).to be_equivalent_graph(nt, logger: @logger)
      end
      
      it "should create BNode for [] as subject" do
        ttl = %(@prefix a: <http://foo/a#> . [] a:p a:v .)
        nt = %(_:bnode0 <http://foo/a#p> <http://foo/a#v> .)
        g = parse(ttl, base_uri:  "http://a/b")
        expect(g).to be_equivalent_graph(nt, about:  "http://a/b", logger: @logger)
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
        expect(parse(ttl)).to be_equivalent_graph(nt, logger: @logger)
      end
      
      it "creates BNode for [] as statement" do
        ttl = %([<a> <b>] .)
        nt = %(_:a <a> <b> .)
        expect(parse(ttl, validate:  false)).to be_equivalent_graph(nt, logger: @logger)
      end
      
      it "should create BNode as a single object" do
        ttl = %q(@prefix a: <http://foo/a#> . a:b a:oneRef [ a:pp "1" ; a:qq "2" ] .)
        nt = %(
        _:a <http://foo/a#pp> "1" .
        _:a <http://foo/a#qq> "2" .
        <http://foo/a#b> <http://foo/a#oneRef> _:a .
        )
        expect(parse(ttl, validate:  false)).to be_equivalent_graph(nt, logger: @logger)
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
        expect(parse(ttl, validate: false, prefixes:  {nil => ''})).to be_equivalent_graph(nt, logger: @logger)
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
        expect(parse(ttl, validate: false, prefixes:  {nil => ''})).to be_equivalent_graph(nt, logger: @logger)
      end
    end

    describe "blankNodePropertyList" do
      {
        "sole_blankNodePropertyList" => [
          %([ <http://a.example/p> <http://a.example/o> ] .),
          %(_:a <http://a.example/p> <http://a.example/o> .)
        ]
      }.each do |name, (ttl, nt)|
        it name do
          expect(parse(ttl, validate: true)).to be_equivalent_graph(nt, logger: @logger)
        end
      end
    end

    describe "objectList" do
      {
        "IRIs" => [
          %(<a> <b> <c>, <d>.),
          %(
            <a> <b> <c> .
            <a> <b> <d> .
          )
        ],
        "literals" => [
          %(<a> <b> "1", "2" .),
          %(
            <a> <b> "1" .
            <a> <b> "2" .
          )
        ],
        "mixed" => [
          %(<a> <b> <c>, "2" .),
          %(
            <a> <b> <c> .
            <a> <b> "2" .
          )
        ],
      }.each do |name, (ttl, nt)|
        it name do
          expect(parse(ttl, validate: false)).to be_equivalent_graph(nt, logger: @logger)
        end
      end
    end
    
    describe "predicateObjectList" do
      {
        "mixed" => [
          %(
            @prefix a: <http://foo/a#> .

            a:b a:p1 "123" ; a:p1 "456" .
            a:b a:p2 a:v1 ; a:p3 a:v2 .
          ),
          %(
            <http://foo/a#b> <http://foo/a#p1> "123" .
            <http://foo/a#b> <http://foo/a#p1> "456" .
            <http://foo/a#b> <http://foo/a#p2> <http://foo/a#v1> .
            <http://foo/a#b> <http://foo/a#p3> <http://foo/a#v2> .
          )
        ],
      }.each do |name, (ttl, nt)|
        it name do
          expect(parse(ttl)).to be_equivalent_graph(nt, logger: @logger)
        end
      end
    end
    
    describe "collection" do
      it "empty list" do
        ttl = %(@prefix :<http://example.com/>. :empty :set ().)
        nt = %(
        <http://example.com/empty> <http://example.com/set> <http://www.w3.org/1999/02/22-rdf-syntax-ns#nil> .)
        expect(parse(ttl)).to be_equivalent_graph(nt, logger: @logger)
      end
      
      it "single element" do
        ttl = %(@prefix :<http://example.com/>. :gregg :wrote ("RdfContext").)
        nt = %(
        _:bnode0 <http://www.w3.org/1999/02/22-rdf-syntax-ns#first> "RdfContext" .
        _:bnode0 <http://www.w3.org/1999/02/22-rdf-syntax-ns#rest> <http://www.w3.org/1999/02/22-rdf-syntax-ns#nil> .
        <http://example.com/gregg> <http://example.com/wrote> _:bnode0 .
        )
        expect(parse(ttl)).to be_equivalent_graph(nt, logger: @logger)
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
        expect(parse(ttl)).to be_equivalent_graph(nt, logger: @logger)
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
        expect(parse(ttl, validate:  false)).to be_equivalent_graph(nt, logger: @logger)
      end
      
      it "adds property to nil list" do
        ttl = %(@prefix a: <http://foo/a#> . () a:prop "nilProp" .)
        nt = %(<http://www.w3.org/1999/02/22-rdf-syntax-ns#nil> <http://foo/a#prop> "nilProp" .)
        expect(parse(ttl)).to be_equivalent_graph(nt, logger: @logger)
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
        expect(parse(ttl, validate: false, prefixes:  {nil => ''})).to be_equivalent_graph(nt, logger: @logger)
      end
    end
  end

  context "RDF*" do
    {
      "subject-iii" => [
        %(
          @prefix ex: <http://example/> .
          <<ex:s1 ex:p1 ex:o1>> ex:p ex:o .
        ),
        %(
          <<<http://example/s1> <http://example/p1> <http://example/o1>>> <http://example/p> <http://example/o> .
          <http://example/s1> <http://example/p1> <http://example/o1> .
        )
      ],
      "subject-iib": [
        %(
          @prefix ex: <http://example/> .
          <<ex:s1 ex:p1 _:o1>> ex:p ex:o .
        ),
        %(
          <<<http://example/s1> <http://example/p1> _:o1>> <http://example/p> <http://example/o> .
          <http://example/s1> <http://example/p1> _:o1 .
        )
      ],
      "subject-iil": [
        %(
          @prefix ex: <http://example/> .
          <<ex:s1 ex:p1 "o1">> ex:p ex:o .
        ),
        %(
          <<<http://example/s1> <http://example/p1> "o1">> <http://example/p> <http://example/o> .
          <http://example/s1> <http://example/p1> "o1"
        )
      ],
      "subject-bii": [
        %(
          @prefix ex: <http://example/> .
          <<_:s1 ex:p1 ex:o1>> ex:p ex:o .
        ),
        %(
          <<_:s1 <http://example/p1> <http://example/o1>>> <http://example/p> <http://example/o> .
          _:s1 <http://example/p1> <http://example/o1> .
        )
      ],
      "subject-bib": [
        %(
          @prefix ex: <http://example/> .
          <<_:s1 ex:p1 _:o1>> ex:p ex:o .
        ),
        %(
          <<_:s1 <http://example/p1> _:o1>> <http://example/p> <http://example/o> .
          _:s1 <http://example/p1> _:o1 .
        )
      ],
      "subject-bil": [
        %(
          @prefix ex: <http://example/> .
          <<_:s1 ex:p1 "o1">> ex:p ex:o .
        ),
        %(
          <<_:s1 <http://example/p1> "o1">> <http://example/p> <http://example/o> .
          _:s1 <http://example/p1> "o1" .
        )
      ],
      "object-iii":  [
        %(
          @prefix ex: <http://example/> .
          ex:s ex:p <<ex:s1 ex:p1 ex:o1>> .
        ),
        %(
          <http://example/s> <http://example/p> <<<http://example/s1> <http://example/p1> <http://example/o1>>> .
          <http://example/s1> <http://example/p1> <http://example/o1> .
        )
      ],
      "object-iib":  [
        %(
          @prefix ex: <http://example/> .
          ex:s ex:p <<ex:s1 ex:p1 _:o1>> .
        ),
        %(
          <http://example/s> <http://example/p> <<<http://example/s1> <http://example/p1> _:o1>> .
          <http://example/s1> <http://example/p1> _:o1
        )
      ],
      "object-iil":  [
        %(
          @prefix ex: <http://example/> .
          ex:s ex:p <<ex:s1 ex:p1 "o1">> .
        ),
        %(
          <http://example/s> <http://example/p> <<<http://example/s1> <http://example/p1> "o1">> .
          <http://example/s1> <http://example/p1> "o1" .
        )
      ],
      "recursive-subject": [
        %(
          @prefix ex: <http://example/> .
          <<
            <<ex:s2 ex:p2 ex:o2>>
              ex:p1 ex:o1 >>
            ex:p ex:o .
        ),
        %(
          <<<<<http://example/s2> <http://example/p2> <http://example/o2>>> <http://example/p1> <http://example/o1>>> <http://example/p> <http://example/o> .
          <<<http://example/s2> <http://example/p2> <http://example/o2>>> <http://example/p1> <http://example/o1> .
          <http://example/s2> <http://example/p2> <http://example/o2> .
        )
      ],
    }.each do |name, (ttl, nt)|
      it name do
        expect_graph = RDF::Graph.new {|g| g << RDF::NTriples::Reader.new(nt, rdfstar: :PG)}
        expect(parse(ttl, rdfstar: :PG, validate: true)).to be_equivalent_graph(expect_graph, logger: @logger)
      end
    end
  end

  describe "canonicalization" do
    {
      %("+1"^^xsd:integer)  => %("1"^^<http://www.w3.org/2001/XMLSchema#integer>),
      %(+1)                 => %("1"^^<http://www.w3.org/2001/XMLSchema#integer>),
      %(.1)                 => %("0.1"^^<http://www.w3.org/2001/XMLSchema#decimal>),
      %(123.E+1)            => %("1.23E3"^^<http://www.w3.org/2001/XMLSchema#double>),
      %(true)               => %("true"^^<http://www.w3.org/2001/XMLSchema#boolean>),
      %("lang"@EN)          => %("lang"@en),
      %("""lang"""@EN)      => %("lang"@en),
      %("""+1"""^^xsd:integer)  => %("1"^^<http://www.w3.org/2001/XMLSchema#integer>),
      %(<http://example/Dürst>) => %(<http://example/Dürst>)
    }.each_pair do |input, result|
      it "returns object #{result} given #{input}" do
        ttl = %(@prefix xsd: <http://www.w3.org/2001/XMLSchema#> . <http://example/a> <http://example/b> #{input} .)
        nt = %(<http://example/a> <http://example/b> #{result} .)
        expect(parse(ttl, canonicalize:  true)).to be_equivalent_graph(nt, logger: @logger)
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
            @expected = RDF::Graph.new << RDF::Statement(RDF::URI(""), RDF.value, RDF::Literal.new(value, datatype:  dt_uri))
          end

          context "with #{value}" do
            it "creates triple with invalid literal" do
              expect(parse(@input, validate:  false)).to be_equivalent_graph(@expected, logger: @logger)
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
    let(:errors) {[]}
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
      context ttl do
        it "should raise '#{error}' for '#{ttl}'" do
          expect {
            parse("@prefix xsd: <http://www.w3.org/2001/XMLSchema#> . #{ttl}",
              base_uri:  "http://a/b",
              errors: errors,
              validate:  true)
          }.to raise_error(RDF::ReaderError)

          expect(@logger.to_s).to match(error) if error.is_a?(Regexp)
        end
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
        %q()
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
        )
      ],
    }.each do |test, (input, expected)|
      context test do
        it "raises an error if valiating" do
          expect {parse(input, validate:  true)}.to raise_error RDF::ReaderError
        end

        it "continues after an error" do
          expect(parse(input, validate:  false)).to be_equivalent_graph(expected, logger: @logger)
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
      <urn:ex:s001> <urn:ex:p> <g:h>.
      <urn:ex:s002> <urn:ex:p> <g>.
      <urn:ex:s003> <urn:ex:p> <./g>.
      <urn:ex:s004> <urn:ex:p> <g/>.
      <urn:ex:s005> <urn:ex:p> </g>.
      <urn:ex:s006> <urn:ex:p> <//g>.
      <urn:ex:s007> <urn:ex:p> <?y>.
      <urn:ex:s008> <urn:ex:p> <g?y>.
      <urn:ex:s009> <urn:ex:p> <#s>.
      <urn:ex:s010> <urn:ex:p> <g#s>.
      <urn:ex:s011> <urn:ex:p> <g?y#s>.
      <urn:ex:s012> <urn:ex:p> <;x>.
      <urn:ex:s013> <urn:ex:p> <g;x>.
      <urn:ex:s014> <urn:ex:p> <g;x?y#s>.
      <urn:ex:s015> <urn:ex:p> <>.
      <urn:ex:s016> <urn:ex:p> <.>.
      <urn:ex:s017> <urn:ex:p> <./>.
      <urn:ex:s018> <urn:ex:p> <..>.
      <urn:ex:s019> <urn:ex:p> <../>.
      <urn:ex:s020> <urn:ex:p> <../g>.
      <urn:ex:s021> <urn:ex:p> <../..>.
      <urn:ex:s022> <urn:ex:p> <../../>.
      <urn:ex:s023> <urn:ex:p> <../../g>.

      # RFC3986 abnormal examples
      @base <http://a/bb/ccc/d;p?q>.
      <urn:ex:s024> <urn:ex:p> <../../../g>.
      <urn:ex:s025> <urn:ex:p> <../../../../g>.
      <urn:ex:s026> <urn:ex:p> </./g>.
      <urn:ex:s027> <urn:ex:p> </../g>.
      <urn:ex:s028> <urn:ex:p> <g.>.
      <urn:ex:s029> <urn:ex:p> <.g>.
      <urn:ex:s030> <urn:ex:p> <g..>.
      <urn:ex:s031> <urn:ex:p> <..g>.
      <urn:ex:s032> <urn:ex:p> <./../g>.
      <urn:ex:s033> <urn:ex:p> <./g/.>.
      <urn:ex:s034> <urn:ex:p> <g/./h>.
      <urn:ex:s035> <urn:ex:p> <g/../h>.
      <urn:ex:s036> <urn:ex:p> <g;x=1/./y>.
      <urn:ex:s037> <urn:ex:p> <g;x=1/../y>.
      <urn:ex:s038> <urn:ex:p> <g?y/./x>.
      <urn:ex:s039> <urn:ex:p> <g?y/../x>.
      <urn:ex:s040> <urn:ex:p> <g#s/./x>.
      <urn:ex:s041> <urn:ex:p> <g#s/../x>.
      <urn:ex:s042> <urn:ex:p> <http:g>.

      # RFC3986 normal examples with trailing slash in base IRI
      @base <http://a/bb/ccc/d/>.
      <urn:ex:s043> <urn:ex:p> <g:h>.
      <urn:ex:s044> <urn:ex:p> <g>.
      <urn:ex:s045> <urn:ex:p> <./g>.
      <urn:ex:s046> <urn:ex:p> <g/>.
      <urn:ex:s047> <urn:ex:p> </g>.
      <urn:ex:s048> <urn:ex:p> <//g>.
      <urn:ex:s049> <urn:ex:p> <?y>.
      <urn:ex:s050> <urn:ex:p> <g?y>.
      <urn:ex:s051> <urn:ex:p> <#s>.
      <urn:ex:s052> <urn:ex:p> <g#s>.
      <urn:ex:s053> <urn:ex:p> <g?y#s>.
      <urn:ex:s054> <urn:ex:p> <;x>.
      <urn:ex:s055> <urn:ex:p> <g;x>.
      <urn:ex:s056> <urn:ex:p> <g;x?y#s>.
      <urn:ex:s057> <urn:ex:p> <>.
      <urn:ex:s058> <urn:ex:p> <.>.
      <urn:ex:s059> <urn:ex:p> <./>.
      <urn:ex:s060> <urn:ex:p> <..>.
      <urn:ex:s061> <urn:ex:p> <../>.
      <urn:ex:s062> <urn:ex:p> <../g>.
      <urn:ex:s063> <urn:ex:p> <../..>.
      <urn:ex:s064> <urn:ex:p> <../../>.
      <urn:ex:s065> <urn:ex:p> <../../g>.

      # RFC3986 abnormal examples with trailing slash in base IRI
      @base <http://a/bb/ccc/d/>.
      <urn:ex:s066> <urn:ex:p> <../../../g>.
      <urn:ex:s067> <urn:ex:p> <../../../../g>.
      <urn:ex:s068> <urn:ex:p> </./g>.
      <urn:ex:s069> <urn:ex:p> </../g>.
      <urn:ex:s070> <urn:ex:p> <g.>.
      <urn:ex:s071> <urn:ex:p> <.g>.
      <urn:ex:s072> <urn:ex:p> <g..>.
      <urn:ex:s073> <urn:ex:p> <..g>.
      <urn:ex:s074> <urn:ex:p> <./../g>.
      <urn:ex:s075> <urn:ex:p> <./g/.>.
      <urn:ex:s076> <urn:ex:p> <g/./h>.
      <urn:ex:s077> <urn:ex:p> <g/../h>.
      <urn:ex:s078> <urn:ex:p> <g;x=1/./y>.
      <urn:ex:s079> <urn:ex:p> <g;x=1/../y>.
      <urn:ex:s080> <urn:ex:p> <g?y/./x>.
      <urn:ex:s081> <urn:ex:p> <g?y/../x>.
      <urn:ex:s082> <urn:ex:p> <g#s/./x>.
      <urn:ex:s083> <urn:ex:p> <g#s/../x>.
      <urn:ex:s084> <urn:ex:p> <http:g>.

      # RFC3986 normal examples with /. in the base IRI
      @base <http://a/bb/ccc/./d;p?q>.
      <urn:ex:s085> <urn:ex:p> <g:h>.
      <urn:ex:s086> <urn:ex:p> <g>.
      <urn:ex:s087> <urn:ex:p> <./g>.
      <urn:ex:s088> <urn:ex:p> <g/>.
      <urn:ex:s089> <urn:ex:p> </g>.
      <urn:ex:s090> <urn:ex:p> <//g>.
      <urn:ex:s091> <urn:ex:p> <?y>.
      <urn:ex:s092> <urn:ex:p> <g?y>.
      <urn:ex:s093> <urn:ex:p> <#s>.
      <urn:ex:s094> <urn:ex:p> <g#s>.
      <urn:ex:s095> <urn:ex:p> <g?y#s>.
      <urn:ex:s096> <urn:ex:p> <;x>.
      <urn:ex:s097> <urn:ex:p> <g;x>.
      <urn:ex:s098> <urn:ex:p> <g;x?y#s>.
      <urn:ex:s099> <urn:ex:p> <>.
      <urn:ex:s100> <urn:ex:p> <.>.
      <urn:ex:s101> <urn:ex:p> <./>.
      <urn:ex:s102> <urn:ex:p> <..>.
      <urn:ex:s103> <urn:ex:p> <../>.
      <urn:ex:s104> <urn:ex:p> <../g>.
      <urn:ex:s105> <urn:ex:p> <../..>.
      <urn:ex:s106> <urn:ex:p> <../../>.
      <urn:ex:s107> <urn:ex:p> <../../g>.

      # RFC3986 abnormal examples with /. in the base IRI
      @base <http://a/bb/ccc/./d;p?q>.
      <urn:ex:s108> <urn:ex:p> <../../../g>.
      <urn:ex:s109> <urn:ex:p> <../../../../g>.
      <urn:ex:s110> <urn:ex:p> </./g>.
      <urn:ex:s111> <urn:ex:p> </../g>.
      <urn:ex:s112> <urn:ex:p> <g.>.
      <urn:ex:s113> <urn:ex:p> <.g>.
      <urn:ex:s114> <urn:ex:p> <g..>.
      <urn:ex:s115> <urn:ex:p> <..g>.
      <urn:ex:s116> <urn:ex:p> <./../g>.
      <urn:ex:s117> <urn:ex:p> <./g/.>.
      <urn:ex:s118> <urn:ex:p> <g/./h>.
      <urn:ex:s119> <urn:ex:p> <g/../h>.
      <urn:ex:s120> <urn:ex:p> <g;x=1/./y>.
      <urn:ex:s121> <urn:ex:p> <g;x=1/../y>.
      <urn:ex:s122> <urn:ex:p> <g?y/./x>.
      <urn:ex:s123> <urn:ex:p> <g?y/../x>.
      <urn:ex:s124> <urn:ex:p> <g#s/./x>.
      <urn:ex:s125> <urn:ex:p> <g#s/../x>.
      <urn:ex:s126> <urn:ex:p> <http:g>.

      # RFC3986 normal examples with /.. in the base IRI
      @base <http://a/bb/ccc/../d;p?q>.
      <urn:ex:s127> <urn:ex:p> <g:h>.
      <urn:ex:s128> <urn:ex:p> <g>.
      <urn:ex:s129> <urn:ex:p> <./g>.
      <urn:ex:s130> <urn:ex:p> <g/>.
      <urn:ex:s131> <urn:ex:p> </g>.
      <urn:ex:s132> <urn:ex:p> <//g>.
      <urn:ex:s133> <urn:ex:p> <?y>.
      <urn:ex:s134> <urn:ex:p> <g?y>.
      <urn:ex:s135> <urn:ex:p> <#s>.
      <urn:ex:s136> <urn:ex:p> <g#s>.
      <urn:ex:s137> <urn:ex:p> <g?y#s>.
      <urn:ex:s138> <urn:ex:p> <;x>.
      <urn:ex:s139> <urn:ex:p> <g;x>.
      <urn:ex:s140> <urn:ex:p> <g;x?y#s>.
      <urn:ex:s141> <urn:ex:p> <>.
      <urn:ex:s142> <urn:ex:p> <.>.
      <urn:ex:s143> <urn:ex:p> <./>.
      <urn:ex:s144> <urn:ex:p> <..>.
      <urn:ex:s145> <urn:ex:p> <../>.
      <urn:ex:s146> <urn:ex:p> <../g>.
      <urn:ex:s147> <urn:ex:p> <../..>.
      <urn:ex:s148> <urn:ex:p> <../../>.
      <urn:ex:s149> <urn:ex:p> <../../g>.

      # RFC3986 abnormal examples with /.. in the base IRI
      @base <http://a/bb/ccc/../d;p?q>.
      <urn:ex:s150> <urn:ex:p> <../../../g>.
      <urn:ex:s151> <urn:ex:p> <../../../../g>.
      <urn:ex:s152> <urn:ex:p> </./g>.
      <urn:ex:s153> <urn:ex:p> </../g>.
      <urn:ex:s154> <urn:ex:p> <g.>.
      <urn:ex:s155> <urn:ex:p> <.g>.
      <urn:ex:s156> <urn:ex:p> <g..>.
      <urn:ex:s157> <urn:ex:p> <..g>.
      <urn:ex:s158> <urn:ex:p> <./../g>.
      <urn:ex:s159> <urn:ex:p> <./g/.>.
      <urn:ex:s160> <urn:ex:p> <g/./h>.
      <urn:ex:s161> <urn:ex:p> <g/../h>.
      <urn:ex:s162> <urn:ex:p> <g;x=1/./y>.
      <urn:ex:s163> <urn:ex:p> <g;x=1/../y>.
      <urn:ex:s164> <urn:ex:p> <g?y/./x>.
      <urn:ex:s165> <urn:ex:p> <g?y/../x>.
      <urn:ex:s166> <urn:ex:p> <g#s/./x>.
      <urn:ex:s167> <urn:ex:p> <g#s/../x>.
      <urn:ex:s168> <urn:ex:p> <http:g>.

      # RFC3986 normal examples with trailing /. in the base IRI
      @base <http://a/bb/ccc/.>.
      <urn:ex:s169> <urn:ex:p> <g:h>.
      <urn:ex:s170> <urn:ex:p> <g>.
      <urn:ex:s171> <urn:ex:p> <./g>.
      <urn:ex:s172> <urn:ex:p> <g/>.
      <urn:ex:s173> <urn:ex:p> </g>.
      <urn:ex:s174> <urn:ex:p> <//g>.
      <urn:ex:s175> <urn:ex:p> <?y>.
      <urn:ex:s176> <urn:ex:p> <g?y>.
      <urn:ex:s177> <urn:ex:p> <#s>.
      <urn:ex:s178> <urn:ex:p> <g#s>.
      <urn:ex:s179> <urn:ex:p> <g?y#s>.
      <urn:ex:s180> <urn:ex:p> <;x>.
      <urn:ex:s181> <urn:ex:p> <g;x>.
      <urn:ex:s182> <urn:ex:p> <g;x?y#s>.
      <urn:ex:s183> <urn:ex:p> <>.
      <urn:ex:s184> <urn:ex:p> <.>.
      <urn:ex:s185> <urn:ex:p> <./>.
      <urn:ex:s186> <urn:ex:p> <..>.
      <urn:ex:s187> <urn:ex:p> <../>.
      <urn:ex:s188> <urn:ex:p> <../g>.
      <urn:ex:s189> <urn:ex:p> <../..>.
      <urn:ex:s190> <urn:ex:p> <../../>.
      <urn:ex:s191> <urn:ex:p> <../../g>.

      # RFC3986 abnormal examples with trailing /. in the base IRI
      @base <http://a/bb/ccc/.>.
      <urn:ex:s192> <urn:ex:p> <../../../g>.
      <urn:ex:s193> <urn:ex:p> <../../../../g>.
      <urn:ex:s194> <urn:ex:p> </./g>.
      <urn:ex:s195> <urn:ex:p> </../g>.
      <urn:ex:s196> <urn:ex:p> <g.>.
      <urn:ex:s197> <urn:ex:p> <.g>.
      <urn:ex:s198> <urn:ex:p> <g..>.
      <urn:ex:s199> <urn:ex:p> <..g>.
      <urn:ex:s200> <urn:ex:p> <./../g>.
      <urn:ex:s201> <urn:ex:p> <./g/.>.
      <urn:ex:s202> <urn:ex:p> <g/./h>.
      <urn:ex:s203> <urn:ex:p> <g/../h>.
      <urn:ex:s204> <urn:ex:p> <g;x=1/./y>.
      <urn:ex:s205> <urn:ex:p> <g;x=1/../y>.
      <urn:ex:s206> <urn:ex:p> <g?y/./x>.
      <urn:ex:s207> <urn:ex:p> <g?y/../x>.
      <urn:ex:s208> <urn:ex:p> <g#s/./x>.
      <urn:ex:s209> <urn:ex:p> <g#s/../x>.
      <urn:ex:s210> <urn:ex:p> <http:g>.

      # RFC3986 normal examples with trailing /.. in the base IRI
      @base <http://a/bb/ccc/..>.
      <urn:ex:s211> <urn:ex:p> <g:h>.
      <urn:ex:s212> <urn:ex:p> <g>.
      <urn:ex:s213> <urn:ex:p> <./g>.
      <urn:ex:s214> <urn:ex:p> <g/>.
      <urn:ex:s215> <urn:ex:p> </g>.
      <urn:ex:s216> <urn:ex:p> <//g>.
      <urn:ex:s217> <urn:ex:p> <?y>.
      <urn:ex:s218> <urn:ex:p> <g?y>.
      <urn:ex:s219> <urn:ex:p> <#s>.
      <urn:ex:s220> <urn:ex:p> <g#s>.
      <urn:ex:s221> <urn:ex:p> <g?y#s>.
      <urn:ex:s222> <urn:ex:p> <;x>.
      <urn:ex:s223> <urn:ex:p> <g;x>.
      <urn:ex:s224> <urn:ex:p> <g;x?y#s>.
      <urn:ex:s225> <urn:ex:p> <>.
      <urn:ex:s226> <urn:ex:p> <.>.
      <urn:ex:s227> <urn:ex:p> <./>.
      <urn:ex:s228> <urn:ex:p> <..>.
      <urn:ex:s229> <urn:ex:p> <../>.
      <urn:ex:s230> <urn:ex:p> <../g>.
      <urn:ex:s231> <urn:ex:p> <../..>.
      <urn:ex:s232> <urn:ex:p> <../../>.
      <urn:ex:s233> <urn:ex:p> <../../g>.

      # RFC3986 abnormal examples with trailing /.. in the base IRI
      @base <http://a/bb/ccc/..>.
      <urn:ex:s234> <urn:ex:p> <../../../g>.
      <urn:ex:s235> <urn:ex:p> <../../../../g>.
      <urn:ex:s236> <urn:ex:p> </./g>.
      <urn:ex:s237> <urn:ex:p> </../g>.
      <urn:ex:s238> <urn:ex:p> <g.>.
      <urn:ex:s239> <urn:ex:p> <.g>.
      <urn:ex:s240> <urn:ex:p> <g..>.
      <urn:ex:s241> <urn:ex:p> <..g>.
      <urn:ex:s242> <urn:ex:p> <./../g>.
      <urn:ex:s243> <urn:ex:p> <./g/.>.
      <urn:ex:s244> <urn:ex:p> <g/./h>.
      <urn:ex:s245> <urn:ex:p> <g/../h>.
      <urn:ex:s246> <urn:ex:p> <g;x=1/./y>.
      <urn:ex:s247> <urn:ex:p> <g;x=1/../y>.
      <urn:ex:s248> <urn:ex:p> <g?y/./x>.
      <urn:ex:s249> <urn:ex:p> <g?y/../x>.
      <urn:ex:s250> <urn:ex:p> <g#s/./x>.
      <urn:ex:s251> <urn:ex:p> <g#s/../x>.
      <urn:ex:s252> <urn:ex:p> <http:g>.

      # RFC3986 normal examples with file path
      @base <file:///a/bb/ccc/d;p?q>.
      <urn:ex:s253> <urn:ex:p> <g:h>.
      <urn:ex:s254> <urn:ex:p> <g>.
      <urn:ex:s255> <urn:ex:p> <./g>.
      <urn:ex:s256> <urn:ex:p> <g/>.
      <urn:ex:s257> <urn:ex:p> </g>.
      <urn:ex:s258> <urn:ex:p> <//g>.
      <urn:ex:s259> <urn:ex:p> <?y>.
      <urn:ex:s260> <urn:ex:p> <g?y>.
      <urn:ex:s261> <urn:ex:p> <#s>.
      <urn:ex:s262> <urn:ex:p> <g#s>.
      <urn:ex:s263> <urn:ex:p> <g?y#s>.
      <urn:ex:s264> <urn:ex:p> <;x>.
      <urn:ex:s265> <urn:ex:p> <g;x>.
      <urn:ex:s266> <urn:ex:p> <g;x?y#s>.
      <urn:ex:s267> <urn:ex:p> <>.
      <urn:ex:s268> <urn:ex:p> <.>.
      <urn:ex:s269> <urn:ex:p> <./>.
      <urn:ex:s270> <urn:ex:p> <..>.
      <urn:ex:s271> <urn:ex:p> <../>.
      <urn:ex:s272> <urn:ex:p> <../g>.
      <urn:ex:s273> <urn:ex:p> <../..>.
      <urn:ex:s274> <urn:ex:p> <../../>.
      <urn:ex:s275> <urn:ex:p> <../../g>.

      # RFC3986 abnormal examples with file path
      @base <file:///a/bb/ccc/d;p?q>.
      <urn:ex:s276> <urn:ex:p> <../../../g>.
      <urn:ex:s277> <urn:ex:p> <../../../../g>.
      <urn:ex:s278> <urn:ex:p> </./g>.
      <urn:ex:s279> <urn:ex:p> </../g>.
      <urn:ex:s280> <urn:ex:p> <g.>.
      <urn:ex:s281> <urn:ex:p> <.g>.
      <urn:ex:s282> <urn:ex:p> <g..>.
      <urn:ex:s283> <urn:ex:p> <..g>.
      <urn:ex:s284> <urn:ex:p> <./../g>.
      <urn:ex:s285> <urn:ex:p> <./g/.>.
      <urn:ex:s286> <urn:ex:p> <g/./h>.
      <urn:ex:s287> <urn:ex:p> <g/../h>.
      <urn:ex:s288> <urn:ex:p> <g;x=1/./y>.
      <urn:ex:s289> <urn:ex:p> <g;x=1/../y>.
      <urn:ex:s290> <urn:ex:p> <g?y/./x>.
      <urn:ex:s291> <urn:ex:p> <g?y/../x>.
      <urn:ex:s292> <urn:ex:p> <g#s/./x>.
      <urn:ex:s293> <urn:ex:p> <g#s/../x>.
      <urn:ex:s294> <urn:ex:p> <http:g>.

      # additional cases
      @base <http://abc/def/ghi>.
      <urn:ex:s295> <urn:ex:p> <.>.
      <urn:ex:s296> <urn:ex:p> <.?a=b>.
      <urn:ex:s297> <urn:ex:p> <.#a=b>.
      <urn:ex:s298> <urn:ex:p> <..>.
      <urn:ex:s299> <urn:ex:p> <..?a=b>.
      <urn:ex:s300> <urn:ex:p> <..#a=b>.
      @base <http://ab//de//ghi>.
      <urn:ex:s301> <urn:ex:p> <xyz>.
      <urn:ex:s302> <urn:ex:p> <./xyz>.
      <urn:ex:s303> <urn:ex:p> <../xyz>.
      @base <http://abc/d:f/ghi>.
      <urn:ex:s304> <urn:ex:p> <xyz>.
      <urn:ex:s305> <urn:ex:p> <./xyz>.
      <urn:ex:s306> <urn:ex:p> <../xyz>.
    }}
    let(:nt) {%q{
      # RFC3986 normal examples

      <urn:ex:s001> <urn:ex:p> <g:h>.
      <urn:ex:s002> <urn:ex:p> <http://a/bb/ccc/g>.
      <urn:ex:s003> <urn:ex:p> <http://a/bb/ccc/g>.
      <urn:ex:s004> <urn:ex:p> <http://a/bb/ccc/g/>.
      <urn:ex:s005> <urn:ex:p> <http://a/g>.
      <urn:ex:s006> <urn:ex:p> <http://g>.
      <urn:ex:s007> <urn:ex:p> <http://a/bb/ccc/d;p?y>.
      <urn:ex:s008> <urn:ex:p> <http://a/bb/ccc/g?y>.
      <urn:ex:s009> <urn:ex:p> <http://a/bb/ccc/d;p?q#s>.
      <urn:ex:s010> <urn:ex:p> <http://a/bb/ccc/g#s>.
      <urn:ex:s011> <urn:ex:p> <http://a/bb/ccc/g?y#s>.
      <urn:ex:s012> <urn:ex:p> <http://a/bb/ccc/;x>.
      <urn:ex:s013> <urn:ex:p> <http://a/bb/ccc/g;x>.
      <urn:ex:s014> <urn:ex:p> <http://a/bb/ccc/g;x?y#s>.
      <urn:ex:s015> <urn:ex:p> <http://a/bb/ccc/d;p?q>.
      <urn:ex:s016> <urn:ex:p> <http://a/bb/ccc/>.
      <urn:ex:s017> <urn:ex:p> <http://a/bb/ccc/>.
      <urn:ex:s018> <urn:ex:p> <http://a/bb/>.
      <urn:ex:s019> <urn:ex:p> <http://a/bb/>.
      <urn:ex:s020> <urn:ex:p> <http://a/bb/g>.
      <urn:ex:s021> <urn:ex:p> <http://a/>.
      <urn:ex:s022> <urn:ex:p> <http://a/>.
      <urn:ex:s023> <urn:ex:p> <http://a/g>.

      # RFC3986 abnormal examples

      <urn:ex:s024> <urn:ex:p> <http://a/g>.
      <urn:ex:s025> <urn:ex:p> <http://a/g>.
      <urn:ex:s026> <urn:ex:p> <http://a/g>.
      <urn:ex:s027> <urn:ex:p> <http://a/g>.
      <urn:ex:s028> <urn:ex:p> <http://a/bb/ccc/g.>.
      <urn:ex:s029> <urn:ex:p> <http://a/bb/ccc/.g>.
      <urn:ex:s030> <urn:ex:p> <http://a/bb/ccc/g..>.
      <urn:ex:s031> <urn:ex:p> <http://a/bb/ccc/..g>.
      <urn:ex:s032> <urn:ex:p> <http://a/bb/g>.
      <urn:ex:s033> <urn:ex:p> <http://a/bb/ccc/g/>.
      <urn:ex:s034> <urn:ex:p> <http://a/bb/ccc/g/h>.
      <urn:ex:s035> <urn:ex:p> <http://a/bb/ccc/h>.
      <urn:ex:s036> <urn:ex:p> <http://a/bb/ccc/g;x=1/y>.
      <urn:ex:s037> <urn:ex:p> <http://a/bb/ccc/y>.
      <urn:ex:s038> <urn:ex:p> <http://a/bb/ccc/g?y/./x>.
      <urn:ex:s039> <urn:ex:p> <http://a/bb/ccc/g?y/../x>.
      <urn:ex:s040> <urn:ex:p> <http://a/bb/ccc/g#s/./x>.
      <urn:ex:s041> <urn:ex:p> <http://a/bb/ccc/g#s/../x>.
      <urn:ex:s042> <urn:ex:p> <http:g>.

      # RFC3986 normal examples with trailing slash in base IRI

      <urn:ex:s043> <urn:ex:p> <g:h>.
      <urn:ex:s044> <urn:ex:p> <http://a/bb/ccc/d/g>.
      <urn:ex:s045> <urn:ex:p> <http://a/bb/ccc/d/g>.
      <urn:ex:s046> <urn:ex:p> <http://a/bb/ccc/d/g/>.
      <urn:ex:s047> <urn:ex:p> <http://a/g>.
      <urn:ex:s048> <urn:ex:p> <http://g>.
      <urn:ex:s049> <urn:ex:p> <http://a/bb/ccc/d/?y>.
      <urn:ex:s050> <urn:ex:p> <http://a/bb/ccc/d/g?y>.
      <urn:ex:s051> <urn:ex:p> <http://a/bb/ccc/d/#s>.
      <urn:ex:s052> <urn:ex:p> <http://a/bb/ccc/d/g#s>.
      <urn:ex:s053> <urn:ex:p> <http://a/bb/ccc/d/g?y#s>.
      <urn:ex:s054> <urn:ex:p> <http://a/bb/ccc/d/;x>.
      <urn:ex:s055> <urn:ex:p> <http://a/bb/ccc/d/g;x>.
      <urn:ex:s056> <urn:ex:p> <http://a/bb/ccc/d/g;x?y#s>.
      <urn:ex:s057> <urn:ex:p> <http://a/bb/ccc/d/>.
      <urn:ex:s058> <urn:ex:p> <http://a/bb/ccc/d/>.
      <urn:ex:s059> <urn:ex:p> <http://a/bb/ccc/d/>.
      <urn:ex:s060> <urn:ex:p> <http://a/bb/ccc/>.
      <urn:ex:s061> <urn:ex:p> <http://a/bb/ccc/>.
      <urn:ex:s062> <urn:ex:p> <http://a/bb/ccc/g>.
      <urn:ex:s063> <urn:ex:p> <http://a/bb/>.
      <urn:ex:s064> <urn:ex:p> <http://a/bb/>.
      <urn:ex:s065> <urn:ex:p> <http://a/bb/g>.

      # RFC3986 abnormal examples with trailing slash in base IRI

      <urn:ex:s066> <urn:ex:p> <http://a/g>.
      <urn:ex:s067> <urn:ex:p> <http://a/g>.
      <urn:ex:s068> <urn:ex:p> <http://a/g>.
      <urn:ex:s069> <urn:ex:p> <http://a/g>.
      <urn:ex:s070> <urn:ex:p> <http://a/bb/ccc/d/g.>.
      <urn:ex:s071> <urn:ex:p> <http://a/bb/ccc/d/.g>.
      <urn:ex:s072> <urn:ex:p> <http://a/bb/ccc/d/g..>.
      <urn:ex:s073> <urn:ex:p> <http://a/bb/ccc/d/..g>.
      <urn:ex:s074> <urn:ex:p> <http://a/bb/ccc/g>.
      <urn:ex:s075> <urn:ex:p> <http://a/bb/ccc/d/g/>.
      <urn:ex:s076> <urn:ex:p> <http://a/bb/ccc/d/g/h>.
      <urn:ex:s077> <urn:ex:p> <http://a/bb/ccc/d/h>.
      <urn:ex:s078> <urn:ex:p> <http://a/bb/ccc/d/g;x=1/y>.
      <urn:ex:s079> <urn:ex:p> <http://a/bb/ccc/d/y>.
      <urn:ex:s080> <urn:ex:p> <http://a/bb/ccc/d/g?y/./x>.
      <urn:ex:s081> <urn:ex:p> <http://a/bb/ccc/d/g?y/../x>.
      <urn:ex:s082> <urn:ex:p> <http://a/bb/ccc/d/g#s/./x>.
      <urn:ex:s083> <urn:ex:p> <http://a/bb/ccc/d/g#s/../x>.
      <urn:ex:s084> <urn:ex:p> <http:g>.

      # RFC3986 normal examples with /. in the base IRI

      <urn:ex:s085> <urn:ex:p> <g:h>.
      <urn:ex:s086> <urn:ex:p> <http://a/bb/ccc/g>.
      <urn:ex:s087> <urn:ex:p> <http://a/bb/ccc/g>.
      <urn:ex:s088> <urn:ex:p> <http://a/bb/ccc/g/>.
      <urn:ex:s089> <urn:ex:p> <http://a/g>.
      <urn:ex:s090> <urn:ex:p> <http://g>.
      <urn:ex:s091> <urn:ex:p> <http://a/bb/ccc/./d;p?y>.
      <urn:ex:s092> <urn:ex:p> <http://a/bb/ccc/g?y>.
      <urn:ex:s093> <urn:ex:p> <http://a/bb/ccc/./d;p?q#s>.
      <urn:ex:s094> <urn:ex:p> <http://a/bb/ccc/g#s>.
      <urn:ex:s095> <urn:ex:p> <http://a/bb/ccc/g?y#s>.
      <urn:ex:s096> <urn:ex:p> <http://a/bb/ccc/;x>.
      <urn:ex:s097> <urn:ex:p> <http://a/bb/ccc/g;x>.
      <urn:ex:s098> <urn:ex:p> <http://a/bb/ccc/g;x?y#s>.
      <urn:ex:s099> <urn:ex:p> <http://a/bb/ccc/./d;p?q>.
      <urn:ex:s100> <urn:ex:p> <http://a/bb/ccc/>.
      <urn:ex:s101> <urn:ex:p> <http://a/bb/ccc/>.
      <urn:ex:s102> <urn:ex:p> <http://a/bb/>.
      <urn:ex:s103> <urn:ex:p> <http://a/bb/>.
      <urn:ex:s104> <urn:ex:p> <http://a/bb/g>.
      <urn:ex:s105> <urn:ex:p> <http://a/>.
      <urn:ex:s106> <urn:ex:p> <http://a/>.
      <urn:ex:s107> <urn:ex:p> <http://a/g>.

      # RFC3986 abnormal examples with /. in the base IRI

      <urn:ex:s108> <urn:ex:p> <http://a/g>.
      <urn:ex:s109> <urn:ex:p> <http://a/g>.
      <urn:ex:s110> <urn:ex:p> <http://a/g>.
      <urn:ex:s111> <urn:ex:p> <http://a/g>.
      <urn:ex:s112> <urn:ex:p> <http://a/bb/ccc/g.>.
      <urn:ex:s113> <urn:ex:p> <http://a/bb/ccc/.g>.
      <urn:ex:s114> <urn:ex:p> <http://a/bb/ccc/g..>.
      <urn:ex:s115> <urn:ex:p> <http://a/bb/ccc/..g>.
      <urn:ex:s116> <urn:ex:p> <http://a/bb/g>.
      <urn:ex:s117> <urn:ex:p> <http://a/bb/ccc/g/>.
      <urn:ex:s118> <urn:ex:p> <http://a/bb/ccc/g/h>.
      <urn:ex:s119> <urn:ex:p> <http://a/bb/ccc/h>.
      <urn:ex:s120> <urn:ex:p> <http://a/bb/ccc/g;x=1/y>.
      <urn:ex:s121> <urn:ex:p> <http://a/bb/ccc/y>.
      <urn:ex:s122> <urn:ex:p> <http://a/bb/ccc/g?y/./x>.
      <urn:ex:s123> <urn:ex:p> <http://a/bb/ccc/g?y/../x>.
      <urn:ex:s124> <urn:ex:p> <http://a/bb/ccc/g#s/./x>.
      <urn:ex:s125> <urn:ex:p> <http://a/bb/ccc/g#s/../x>.
      <urn:ex:s126> <urn:ex:p> <http:g>.

      # RFC3986 normal examples with /.. in the base IRI

      <urn:ex:s127> <urn:ex:p> <g:h>.
      <urn:ex:s128> <urn:ex:p> <http://a/bb/g>.
      <urn:ex:s129> <urn:ex:p> <http://a/bb/g>.
      <urn:ex:s130> <urn:ex:p> <http://a/bb/g/>.
      <urn:ex:s131> <urn:ex:p> <http://a/g>.
      <urn:ex:s132> <urn:ex:p> <http://g>.
      <urn:ex:s133> <urn:ex:p> <http://a/bb/ccc/../d;p?y>.
      <urn:ex:s134> <urn:ex:p> <http://a/bb/g?y>.
      <urn:ex:s135> <urn:ex:p> <http://a/bb/ccc/../d;p?q#s>.
      <urn:ex:s136> <urn:ex:p> <http://a/bb/g#s>.
      <urn:ex:s137> <urn:ex:p> <http://a/bb/g?y#s>.
      <urn:ex:s138> <urn:ex:p> <http://a/bb/;x>.
      <urn:ex:s139> <urn:ex:p> <http://a/bb/g;x>.
      <urn:ex:s140> <urn:ex:p> <http://a/bb/g;x?y#s>.
      <urn:ex:s141> <urn:ex:p> <http://a/bb/ccc/../d;p?q>.
      <urn:ex:s142> <urn:ex:p> <http://a/bb/>.
      <urn:ex:s143> <urn:ex:p> <http://a/bb/>.
      <urn:ex:s144> <urn:ex:p> <http://a/>.
      <urn:ex:s145> <urn:ex:p> <http://a/>.
      <urn:ex:s146> <urn:ex:p> <http://a/g>.
      <urn:ex:s147> <urn:ex:p> <http://a/>.
      <urn:ex:s148> <urn:ex:p> <http://a/>.
      <urn:ex:s149> <urn:ex:p> <http://a/g>.

      # RFC3986 abnormal examples with /.. in the base IRI

      <urn:ex:s150> <urn:ex:p> <http://a/g>.
      <urn:ex:s151> <urn:ex:p> <http://a/g>.
      <urn:ex:s152> <urn:ex:p> <http://a/g>.
      <urn:ex:s153> <urn:ex:p> <http://a/g>.
      <urn:ex:s154> <urn:ex:p> <http://a/bb/g.>.
      <urn:ex:s155> <urn:ex:p> <http://a/bb/.g>.
      <urn:ex:s156> <urn:ex:p> <http://a/bb/g..>.
      <urn:ex:s157> <urn:ex:p> <http://a/bb/..g>.
      <urn:ex:s158> <urn:ex:p> <http://a/g>.
      <urn:ex:s159> <urn:ex:p> <http://a/bb/g/>.
      <urn:ex:s160> <urn:ex:p> <http://a/bb/g/h>.
      <urn:ex:s161> <urn:ex:p> <http://a/bb/h>.
      <urn:ex:s162> <urn:ex:p> <http://a/bb/g;x=1/y>.
      <urn:ex:s163> <urn:ex:p> <http://a/bb/y>.
      <urn:ex:s164> <urn:ex:p> <http://a/bb/g?y/./x>.
      <urn:ex:s165> <urn:ex:p> <http://a/bb/g?y/../x>.
      <urn:ex:s166> <urn:ex:p> <http://a/bb/g#s/./x>.
      <urn:ex:s167> <urn:ex:p> <http://a/bb/g#s/../x>.
      <urn:ex:s168> <urn:ex:p> <http:g>.

      # RFC3986 normal examples with trailing /. in the base IRI

      <urn:ex:s169> <urn:ex:p> <g:h>.
      <urn:ex:s170> <urn:ex:p> <http://a/bb/ccc/g>.
      <urn:ex:s171> <urn:ex:p> <http://a/bb/ccc/g>.
      <urn:ex:s172> <urn:ex:p> <http://a/bb/ccc/g/>.
      <urn:ex:s173> <urn:ex:p> <http://a/g>.
      <urn:ex:s174> <urn:ex:p> <http://g>.
      <urn:ex:s175> <urn:ex:p> <http://a/bb/ccc/.?y>.
      <urn:ex:s176> <urn:ex:p> <http://a/bb/ccc/g?y>.
      <urn:ex:s177> <urn:ex:p> <http://a/bb/ccc/.#s>.
      <urn:ex:s178> <urn:ex:p> <http://a/bb/ccc/g#s>.
      <urn:ex:s179> <urn:ex:p> <http://a/bb/ccc/g?y#s>.
      <urn:ex:s180> <urn:ex:p> <http://a/bb/ccc/;x>.
      <urn:ex:s181> <urn:ex:p> <http://a/bb/ccc/g;x>.
      <urn:ex:s182> <urn:ex:p> <http://a/bb/ccc/g;x?y#s>.
      <urn:ex:s183> <urn:ex:p> <http://a/bb/ccc/.>.
      <urn:ex:s184> <urn:ex:p> <http://a/bb/ccc/>.
      <urn:ex:s185> <urn:ex:p> <http://a/bb/ccc/>.
      <urn:ex:s186> <urn:ex:p> <http://a/bb/>.
      <urn:ex:s187> <urn:ex:p> <http://a/bb/>.
      <urn:ex:s188> <urn:ex:p> <http://a/bb/g>.
      <urn:ex:s189> <urn:ex:p> <http://a/>.
      <urn:ex:s190> <urn:ex:p> <http://a/>.
      <urn:ex:s191> <urn:ex:p> <http://a/g>.

      # RFC3986 abnormal examples with trailing /. in the base IRI

      <urn:ex:s192> <urn:ex:p> <http://a/g>.
      <urn:ex:s193> <urn:ex:p> <http://a/g>.
      <urn:ex:s194> <urn:ex:p> <http://a/g>.
      <urn:ex:s195> <urn:ex:p> <http://a/g>.
      <urn:ex:s196> <urn:ex:p> <http://a/bb/ccc/g.>.
      <urn:ex:s197> <urn:ex:p> <http://a/bb/ccc/.g>.
      <urn:ex:s198> <urn:ex:p> <http://a/bb/ccc/g..>.
      <urn:ex:s199> <urn:ex:p> <http://a/bb/ccc/..g>.
      <urn:ex:s200> <urn:ex:p> <http://a/bb/g>.
      <urn:ex:s201> <urn:ex:p> <http://a/bb/ccc/g/>.
      <urn:ex:s202> <urn:ex:p> <http://a/bb/ccc/g/h>.
      <urn:ex:s203> <urn:ex:p> <http://a/bb/ccc/h>.
      <urn:ex:s204> <urn:ex:p> <http://a/bb/ccc/g;x=1/y>.
      <urn:ex:s205> <urn:ex:p> <http://a/bb/ccc/y>.
      <urn:ex:s206> <urn:ex:p> <http://a/bb/ccc/g?y/./x>.
      <urn:ex:s207> <urn:ex:p> <http://a/bb/ccc/g?y/../x>.
      <urn:ex:s208> <urn:ex:p> <http://a/bb/ccc/g#s/./x>.
      <urn:ex:s209> <urn:ex:p> <http://a/bb/ccc/g#s/../x>.
      <urn:ex:s210> <urn:ex:p> <http:g>.

      # RFC3986 normal examples with trailing /.. in the base IRI

      <urn:ex:s211> <urn:ex:p> <g:h>.
      <urn:ex:s212> <urn:ex:p> <http://a/bb/ccc/g>.
      <urn:ex:s213> <urn:ex:p> <http://a/bb/ccc/g>.
      <urn:ex:s214> <urn:ex:p> <http://a/bb/ccc/g/>.
      <urn:ex:s215> <urn:ex:p> <http://a/g>.
      <urn:ex:s216> <urn:ex:p> <http://g>.
      <urn:ex:s217> <urn:ex:p> <http://a/bb/ccc/..?y>.
      <urn:ex:s218> <urn:ex:p> <http://a/bb/ccc/g?y>.
      <urn:ex:s219> <urn:ex:p> <http://a/bb/ccc/..#s>.
      <urn:ex:s220> <urn:ex:p> <http://a/bb/ccc/g#s>.
      <urn:ex:s221> <urn:ex:p> <http://a/bb/ccc/g?y#s>.
      <urn:ex:s222> <urn:ex:p> <http://a/bb/ccc/;x>.
      <urn:ex:s223> <urn:ex:p> <http://a/bb/ccc/g;x>.
      <urn:ex:s224> <urn:ex:p> <http://a/bb/ccc/g;x?y#s>.
      <urn:ex:s225> <urn:ex:p> <http://a/bb/ccc/..>.
      <urn:ex:s226> <urn:ex:p> <http://a/bb/ccc/>.
      <urn:ex:s227> <urn:ex:p> <http://a/bb/ccc/>.
      <urn:ex:s228> <urn:ex:p> <http://a/bb/>.
      <urn:ex:s229> <urn:ex:p> <http://a/bb/>.
      <urn:ex:s230> <urn:ex:p> <http://a/bb/g>.
      <urn:ex:s231> <urn:ex:p> <http://a/>.
      <urn:ex:s232> <urn:ex:p> <http://a/>.
      <urn:ex:s233> <urn:ex:p> <http://a/g>.

      # RFC3986 abnormal examples with trailing /.. in the base IRI

      <urn:ex:s234> <urn:ex:p> <http://a/g>.
      <urn:ex:s235> <urn:ex:p> <http://a/g>.
      <urn:ex:s236> <urn:ex:p> <http://a/g>.
      <urn:ex:s237> <urn:ex:p> <http://a/g>.
      <urn:ex:s238> <urn:ex:p> <http://a/bb/ccc/g.>.
      <urn:ex:s239> <urn:ex:p> <http://a/bb/ccc/.g>.
      <urn:ex:s240> <urn:ex:p> <http://a/bb/ccc/g..>.
      <urn:ex:s241> <urn:ex:p> <http://a/bb/ccc/..g>.
      <urn:ex:s242> <urn:ex:p> <http://a/bb/g>.
      <urn:ex:s243> <urn:ex:p> <http://a/bb/ccc/g/>.
      <urn:ex:s244> <urn:ex:p> <http://a/bb/ccc/g/h>.
      <urn:ex:s245> <urn:ex:p> <http://a/bb/ccc/h>.
      <urn:ex:s246> <urn:ex:p> <http://a/bb/ccc/g;x=1/y>.
      <urn:ex:s247> <urn:ex:p> <http://a/bb/ccc/y>.
      <urn:ex:s248> <urn:ex:p> <http://a/bb/ccc/g?y/./x>.
      <urn:ex:s249> <urn:ex:p> <http://a/bb/ccc/g?y/../x>.
      <urn:ex:s250> <urn:ex:p> <http://a/bb/ccc/g#s/./x>.
      <urn:ex:s251> <urn:ex:p> <http://a/bb/ccc/g#s/../x>.
      <urn:ex:s252> <urn:ex:p> <http:g>.

      # RFC3986 normal examples with file path

      <urn:ex:s253> <urn:ex:p> <g:h>.
      <urn:ex:s254> <urn:ex:p> <file:///a/bb/ccc/g>.
      <urn:ex:s255> <urn:ex:p> <file:///a/bb/ccc/g>.
      <urn:ex:s256> <urn:ex:p> <file:///a/bb/ccc/g/>.
      <urn:ex:s257> <urn:ex:p> <file:///g>.
      <urn:ex:s258> <urn:ex:p> <file://g>.
      <urn:ex:s259> <urn:ex:p> <file:///a/bb/ccc/d;p?y>.
      <urn:ex:s260> <urn:ex:p> <file:///a/bb/ccc/g?y>.
      <urn:ex:s261> <urn:ex:p> <file:///a/bb/ccc/d;p?q#s>.
      <urn:ex:s262> <urn:ex:p> <file:///a/bb/ccc/g#s>.
      <urn:ex:s263> <urn:ex:p> <file:///a/bb/ccc/g?y#s>.
      <urn:ex:s264> <urn:ex:p> <file:///a/bb/ccc/;x>.
      <urn:ex:s265> <urn:ex:p> <file:///a/bb/ccc/g;x>.
      <urn:ex:s266> <urn:ex:p> <file:///a/bb/ccc/g;x?y#s>.
      <urn:ex:s267> <urn:ex:p> <file:///a/bb/ccc/d;p?q>.
      <urn:ex:s268> <urn:ex:p> <file:///a/bb/ccc/>.
      <urn:ex:s269> <urn:ex:p> <file:///a/bb/ccc/>.
      <urn:ex:s270> <urn:ex:p> <file:///a/bb/>.
      <urn:ex:s271> <urn:ex:p> <file:///a/bb/>.
      <urn:ex:s272> <urn:ex:p> <file:///a/bb/g>.
      <urn:ex:s273> <urn:ex:p> <file:///a/>.
      <urn:ex:s274> <urn:ex:p> <file:///a/>.
      <urn:ex:s275> <urn:ex:p> <file:///a/g>.

      # RFC3986 abnormal examples with file path

      <urn:ex:s276> <urn:ex:p> <file:///g>.
      <urn:ex:s277> <urn:ex:p> <file:///g>.
      <urn:ex:s278> <urn:ex:p> <file:///g>.
      <urn:ex:s279> <urn:ex:p> <file:///g>.
      <urn:ex:s280> <urn:ex:p> <file:///a/bb/ccc/g.>.
      <urn:ex:s281> <urn:ex:p> <file:///a/bb/ccc/.g>.
      <urn:ex:s282> <urn:ex:p> <file:///a/bb/ccc/g..>.
      <urn:ex:s283> <urn:ex:p> <file:///a/bb/ccc/..g>.
      <urn:ex:s284> <urn:ex:p> <file:///a/bb/g>.
      <urn:ex:s285> <urn:ex:p> <file:///a/bb/ccc/g/>.
      <urn:ex:s286> <urn:ex:p> <file:///a/bb/ccc/g/h>.
      <urn:ex:s287> <urn:ex:p> <file:///a/bb/ccc/h>.
      <urn:ex:s288> <urn:ex:p> <file:///a/bb/ccc/g;x=1/y>.
      <urn:ex:s289> <urn:ex:p> <file:///a/bb/ccc/y>.
      <urn:ex:s290> <urn:ex:p> <file:///a/bb/ccc/g?y/./x>.
      <urn:ex:s291> <urn:ex:p> <file:///a/bb/ccc/g?y/../x>.
      <urn:ex:s292> <urn:ex:p> <file:///a/bb/ccc/g#s/./x>.
      <urn:ex:s293> <urn:ex:p> <file:///a/bb/ccc/g#s/../x>.
      <urn:ex:s294> <urn:ex:p> <http:g>.

      # additional cases

      <urn:ex:s295> <urn:ex:p> <http://abc/def/>.
      <urn:ex:s296> <urn:ex:p> <http://abc/def/?a=b>.
      <urn:ex:s297> <urn:ex:p> <http://abc/def/#a=b>.
      <urn:ex:s298> <urn:ex:p> <http://abc/>.
      <urn:ex:s299> <urn:ex:p> <http://abc/?a=b>.
      <urn:ex:s300> <urn:ex:p> <http://abc/#a=b>.

      <urn:ex:s301> <urn:ex:p> <http://ab//de//xyz>.
      <urn:ex:s302> <urn:ex:p> <http://ab//de//xyz>.
      <urn:ex:s303> <urn:ex:p> <http://ab//de/xyz>.

      <urn:ex:s304> <urn:ex:p> <http://abc/d:f/xyz>.
      <urn:ex:s305> <urn:ex:p> <http://abc/d:f/xyz>.
      <urn:ex:s306> <urn:ex:p> <http://abc/xyz>.
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

          <https://www.w3.org/TR/rdf-syntax-grammar>
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

          <https://www.w3.org/TR/rdf-syntax-grammar>
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
        g2 = parse(expected, validate: false)
        g1 = parse(input, validate: false)
        expect(g1).to be_equivalent_graph(g2, logger: @logger)
      end

      it "matches Turtle spec #{name} (ASCII-8BIT io)" do
        g2 = parse(expected, validate: false)
        g1 = parse(StringIO.new(input.force_encoding(Encoding::ASCII_8BIT)), validate: false)
        expect(g1).to be_equivalent_graph(g2, logger: @logger)
      end

      it "matches Turtle spec #{name} (ASCII-8BIT string)" do
        g2 = parse(expected, validate: false)
        g1 = parse(input.force_encoding(Encoding::ASCII_8BIT), validate: false)
        expect(g1).to be_equivalent_graph(g2, logger: @logger)
      end
    end
  end

  def parse(input, **options)
    @logger = RDF::Spec.logger
    options = {
      logger: @logger,
      validate:  true,
      canonicalize:  false,
    }.merge(options)
    graph = options[:graph] || RDF::Graph.new
    RDF::Turtle::Reader.new(input, **options).each do |statement|
      graph << statement
    end
    graph
  end
end
