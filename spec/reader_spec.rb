# coding: utf-8
$:.unshift "."
require File.join(File.dirname(__FILE__), 'spec_helper')

describe "RDF::Turtle::Reader" do
    context "discovery" do
      {
        "etc/foaf.ttl" => RDF::Reader.for("etc/foaf.ttl"),
        "foaf.ttl" => RDF::Reader.for(:file_name      => "foaf.ttl"),
        ".ttl" => RDF::Reader.for(:file_extension => "ttl"),
        "text/turtle" => RDF::Reader.for(:content_type   => "text/turtle"),
      }.each_pair do |label, format|
        it "should discover '#{label}'" do
          format.should == RDF::Turtle::Reader
        end
      end
    end

    context :interface do
      before(:each) do
        @sampledoc = <<-EOF;
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
      EOF
    end
    
    it "should yield reader" do
      inner = mock("inner")
      inner.should_receive(:called).with(RDF::Turtle::Reader)
      RDF::Turtle::Reader.new(@sampledoc) do |reader|
        inner.called(reader.class)
      end
    end
    
    it "should return reader" do
      RDF::Turtle::Reader.new(@sampledoc).should be_a(RDF::Turtle::Reader)
    end
    
    it "should yield statements" do
      inner = mock("inner")
      inner.should_receive(:called).with(RDF::Statement).exactly(15)
      RDF::Turtle::Reader.new(@sampledoc).each_statement do |statement|
        inner.called(statement.class)
      end
    end
    
    it "should yield triples" do
      inner = mock("inner")
      inner.should_receive(:called).exactly(15)
      RDF::Turtle::Reader.new(@sampledoc).each_triple do |subject, predicate, object|
        inner.called(subject.class, predicate.class, object.class)
      end
    end
  end

  describe "with simple ntriples" do
    context "simple triple" do
      before(:each) do
        ttl_string = %(<http://example.org/> <http://xmlns.com/foaf/0.1/name> "Gregg Kellogg" .)
        @graph = parse(ttl_string)
        @statement = @graph.statements.first
      end
      
      it "should have a single triple" do
        @graph.size.should == 1
      end
      
      it "should have subject" do
        @statement.subject.to_s.should == "http://example.org/"
      end
      it "should have predicate" do
        @statement.predicate.to_s.should == "http://xmlns.com/foaf/0.1/name"
      end
      it "should have object" do
        @statement.object.to_s.should == "Gregg Kellogg"
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
          parse(statement).size.should == 0
        end
      end
    end

    describe "with literal encodings" do
      {
        'simple literal' => ':a :b  "simple literal" .',
        'backslash:\\'   => ':a :b  "backslash:\\\\" .',
        'dquote:"'       => ':a :b  "dquote:\\"" .',
        "newline:\n"     => ':a :b  "newline:\\n" .',
        "return\r"       => ':a :b  "return\\r" .',
        "tab:\t"         => ':a :b  "tab:\\t" .',
      }.each_pair do |contents, triple|
        specify "test #{triple}" do
          graph = parse(triple)
          statement = graph.statements.first
          graph.size.should == 1
          statement.object.value.should == contents
        end
      end
      
      {
        'Dürst' => ':a :b "Dürst" .',
        "é" => ':a :b  "é" .',
        "€" => ':a :b  "€" .',
        "resumé" => ':a :resume  "resumé" .',
      }.each_pair do |contents, triple|
        specify "test #{triple}" do
          graph = parse(triple)
          statement = graph.statements.first
          graph.size.should == 1
          statement.object.value.should == contents
        end
      end
      
      it "should parse long literal with escape" do
        ttl = %(@prefix : <http://example.org/foo#> . :a :b "\\U00015678another" .)
        if defined?(::Encoding)
          statement = parse(ttl).statements.first
          statement.object.value.should == "\u{15678}another"
        else
          pending("Not supported in Ruby 1.8")
        end
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
            graph = parse(%(:a :b '''#{string}'''))
            graph.size.should == 1
            graph.statements.first.object.value.should == string
          end

          it "parses LONG2 #{test}" do
            graph = parse(%(:a :b """#{string}"""))
            graph.size.should == 1
            graph.statements.first.object.value.should == string
          end
        end
      end
      
      it "LONG1 matches trailing escaped single-quote" do
        graph = parse(%(:a :b '''\\''''))
        graph.size.should == 1
        graph.statements.first.object.value.should == %q(')
      end
      
      it "LONG2 matches trailing escaped double-quote" do
        graph = parse(%(:a :b """\\""""))
        graph.size.should == 1
        graph.statements.first.object.value.should == %q(")
      end
    end

    it "should create named subject bnode" do
      graph = parse("_:anon <http://example.org/property> <http://example.org/resource2> .")
      graph.size.should == 1
      statement = graph.statements.first
      statement.subject.should be_a(RDF::Node)
      statement.subject.id.should =~ /anon/
      statement.predicate.to_s.should == "http://example.org/property"
      statement.object.to_s.should == "http://example.org/resource2"
    end

    it "raises error with anonymous predicate" do
      lambda {
        parse("<http://example.org/resource2> _:anon <http://example.org/object> .")
      }.should raise_error RDF::ReaderError
    end

    it "ignores anonymous predicate" do
      g = parse("<http://example.org/resource2> _:anon <http://example.org/object> .", :validate => false)
      g.should be_empty
    end

    it "should create named object bnode" do
      graph = parse("<http://example.org/resource2> <http://example.org/property> _:anon .")
      graph.size.should == 1
      statement = graph.statements.first
      statement.subject.to_s.should == "http://example.org/resource2"
      statement.predicate.to_s.should == "http://example.org/property"
      statement.object.should be_a(RDF::Node)
      statement.object.id.should =~ /anon/
    end

    it "should allow mixed-case language" do
      ttl = %(:x2 :p "xyz"@EN .)
      statement = parse(ttl).statements.first
      statement.object.to_ntriples.should == %("xyz"@EN)
    end

    it "should create typed literals" do
      ttl = "<http://example.org/joe> <http://xmlns.com/foaf/0.1/name> \"Joe\" ."
      statement = parse(ttl).statements.first
      statement.object.class.should == RDF::Literal
    end

    it "should create BNodes" do
      ttl = "_:a a _:c ."
      statement = parse(ttl).statements.first
      statement.subject.class.should == RDF::Node
      statement.object.class.should == RDF::Node
    end

    describe "IRIs" do
      {
        %(<http://example.org/joe> <http://xmlns.com/foaf/0.1/knows> <http://example.org/jane> .) =>
          %(<http://example.org/joe> <http://xmlns.com/foaf/0.1/knows> <http://example.org/jane> .),
        %(@base <http://a/b> . <joe> :knows <#jane> .) =>
          %(<http://a/joe> <http://a/bknows> <http://a/b#jane> .),
        %(@base <http://a/b#> . <joe> :knows <#jane> .) =>
          %(<http://a/joe> <http://a/b#knows> <http://a/b#jane> .),
        %(@base <http://a/b/> . <joe> :knows <#jane> .) =>
          %(<http://a/b/joe> <http://a/b/knows> <http://a/b/#jane> .),
        %(@base <http://a/b/> . </joe> :knows <jane> .) =>
          %(<http://a/joe> <http://a/b/knows> <http://a/b/jane> .),
        %(<#D%C3%BCrst>  a  "URI percent ^encoded as C3, BC".) =>
          %(<#D%C3%BCrst> <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> "URI percent ^encoded as C3, BC" .),
      }.each_pair do |ttl, nt|
        it "for '#{ttl}'" do
          parse(ttl).should be_equivalent_graph(nt, :trace => @debug)
        end
      end

      {
        %(<#Dürst> :knows :jane.) => '<#D\u00FCrst> <knows> <jane> .',
        %(:Dürst :knows :jane.) => '<D\u00FCrst> <knows> <jane> .',
        %(:bob :resumé "Bob's non-normalized resumé".) => '<bob> <resumé> "Bob\'s non-normalized resumé" .',
        %(:alice :resumé "Alice's normalized resumé".) => '<alice> <resumé> "Alice\'s normalized resumé" .',
        }.each_pair do |ttl, nt|
          it "for '#{ttl}'" do
            begin
              parse(ttl).should be_equivalent_graph(nt, :trace => @debug)
            rescue
              if defined?(::Encoding)
                raise
              else
                pending("Unicode URIs not supported in Ruby 1.8") {  raise } 
              end
            end
          end
        end

      {
        %(<#Dürst> a  "URI straight in UTF8".) => %(<#D\\u00FCrst> <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> "URI straight in UTF8" .),
        %(:a :related :ひらがな .) => %(<a> <related> <\\u3072\\u3089\\u304C\\u306A> .),
      }.each_pair do |ttl, nt|
        it "for '#{ttl}'" do
          begin
            parse(ttl).should be_equivalent_graph(nt, :trace => @debug)
          rescue
            if defined?(::Encoding)
              raise
            else
              pending("Unicode URIs not supported in Ruby 1.8") {  raise } 
            end
          end
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
          <http://example.org/joe> foaf:name \"Joe\"^^xsd:string .
        )
        statement = parse(ttl).statements.first
        statement.object.class.should == RDF::Literal
      end

      it "empty @prefix" do
        ttl = %(@prefix : <> . <a> a :a.)
        nt = %(<a> <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> <a> .)
        parse(ttl).should be_equivalent_graph(nt, :trace => @debug)
      end
      
      it "<#> as a prefix and as a triple node" do
        ttl = %(@prefix : <#> . <#> a :a.)
        nt = %(
        <#> <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> <#a> .
        )
        parse(ttl).should be_equivalent_graph(nt, :trace => @debug)
      end
      
      it "rdf:type for 'a'" do
        ttl = %(@prefix a: <http://foo/a#> . a:b a <http://www.w3.org/2000/01/rdf-schema#resource> .)
        nt = %(<http://foo/a#b> <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> <http://www.w3.org/2000/01/rdf-schema#resource> .)
        parse(ttl).should be_equivalent_graph(nt, :trace => @debug)
      end
      
      {
        %(:a :b true)  => %(<a> <b> "true"^^<http://www.w3.org/2001/XMLSchema#boolean> .),
        %(:a :b false)  => %(<a> <b> "false"^^<http://www.w3.org/2001/XMLSchema#boolean> .),
        %(:a :b 1)  => %(<a> <b> "1"^^<http://www.w3.org/2001/XMLSchema#integer> .),
        %(:a :b -1)  => %(<a> <b> "-1"^^<http://www.w3.org/2001/XMLSchema#integer> .),
        %(:a :b +1)  => %(<a> <b> "+1"^^<http://www.w3.org/2001/XMLSchema#integer> .),
        %(:a :b 1.0)  => %(<a> <b> "1.0"^^<http://www.w3.org/2001/XMLSchema#decimal> .),
        %(:a :b 1.0e1)  => %(<a> <b> "1.0e1"^^<http://www.w3.org/2001/XMLSchema#double> .),
        %(:a :b 1.0e-1)  => %(<a> <b> "1.0e-1"^^<http://www.w3.org/2001/XMLSchema#double> .),
        %(:a :b 1.0e+1)  => %(<a> <b> "1.0e+1"^^<http://www.w3.org/2001/XMLSchema#double> .),
        %(:a :b 1.0E1)  => %(<a> <b> "1.0e1"^^<http://www.w3.org/2001/XMLSchema#double> .),
      }.each_pair do |ttl, nt|
        it "should create typed literal for '#{ttl}'" do
          parse(ttl).should be_equivalent_graph(nt, :trace => @debug)
        end
      end
      
      it "should accept empty localname" do
        ttl1 = %(: : : .)
        ttl2 = %(<> <> <> .)
        g2 = parse(ttl2)
        parse(ttl1).should be_equivalent_graph(g2, :trace => @debug)
      end
      
      it "should accept prefix with empty local name" do
        ttl = %(@prefix foo: <http://foo/bar#> . foo: foo: foo: .)
        nt = %(<http://foo/bar#> <http://foo/bar#> <http://foo/bar#> .)
        parse(ttl).should be_equivalent_graph(nt, :trace => @debug)
      end
    end
    
    describe "@prefix" do
      it "does not append # for default empty prefix" do
        ttl = %(@prefix : <http://foo/bar> . :a : :b .)
        nt = %(<http://foo/bara> <http://foo/bar> <http://foo/barb> .)
        parse(ttl).should be_equivalent_graph(nt, :trace => @debug)
      end

      it "ignores _ as prefix identifier" do
        ttl = %(
        _:a a :p.
        @prefix _: <http://underscore/> .
        _:a a :q.
        )
        nt = %(
        _:a <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> <p> .
        _:a <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> <q> .
        )
        lambda {parse(ttl)}.should raise_error(RDF::ReaderError)
        parse(ttl, :validate => false).should be_equivalent_graph(nt, :trace => @debug)
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
        parse(ttl).should be_equivalent_graph(nt, :trace => @debug)
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
        reader.prefixes.should == {
          :rdf => "http://www.w3.org/1999/02/22-rdf-syntax-ns#",
          :rdfs => "http://www.w3.org/2000/01/rdf-schema#",
          nil => "http://test/"}
      end
    end

    describe "@base" do
      it "sets absolute base" do
        ttl = %(@base <http://foo/bar> . <> :a <b> . <#c> :d </e>.)
        nt = %(
        <http://foo/bar> <http://foo/bara> <http://foo/b> .
        <http://foo/bar#c> <http://foo/bard> <http://foo/e> .
        )
        parse(ttl).should be_equivalent_graph(nt, :trace => @debug)
      end
      
      it "sets absolute base (trailing /)" do
        ttl = %(@base <http://foo/bar/> . <> :a <b> . <#c> :d </e>.)
        nt = %(
        <http://foo/bar/> <http://foo/bar/a> <http://foo/bar/b> .
        <http://foo/bar/#c> <http://foo/bar/d> <http://foo/e> .
        )
        parse(ttl).should be_equivalent_graph(nt, :trace => @debug)
      end
      
      it "should set absolute base (trailing #)" do
        ttl = %(@base <http://foo/bar#> . <> :a <b> . <#c> :d </e>.)
        nt = %(
        <http://foo/bar#> <http://foo/bar#a> <http://foo/b> .
        <http://foo/bar#c> <http://foo/bar#d> <http://foo/e> .
        )
        parse(ttl).should be_equivalent_graph(nt, :trace => @debug)
      end
      
      it "sets a relative base" do
        ttl = %(
        @base <http://example.org/products/>.
        <> :a <b>, <#c>.
        @base <prod123/>.
        <> :a <b>, <#c>.
        @base <../>.
        <> :a <d>, <#e>.
        )
        nt = %(
        <http://example.org/products/> <http://example.org/products/a> <http://example.org/products/b> .
        <http://example.org/products/> <http://example.org/products/a> <http://example.org/products/#c> .
        <http://example.org/products/prod123/> <http://example.org/products/prod123/a> <http://example.org/products/prod123/b> .
        <http://example.org/products/prod123/> <http://example.org/products/prod123/a> <http://example.org/products/prod123/#c> .
        <http://example.org/products/> <http://example.org/products/a> <http://example.org/products/d> .
        <http://example.org/products/> <http://example.org/products/a> <http://example.org/products/#e> .
        )
        parse(ttl).should be_equivalent_graph(nt, :trace => @debug)
      end
      
      it "redefine" do
        ttl = %(
        @base <http://example.com/ontolgies>. <a> :b <foo/bar#baz>.
        @base <path/DIFFERENT/>. <a2> :b2 <foo/bar#baz2>.
        @prefix : <#>. <d3> :b3 <e3>.
        )
        nt = %(
        <http://example.com/a> <http://example.com/ontolgiesb> <http://example.com/foo/bar#baz> .
        <http://example.com/path/DIFFERENT/a2> <http://example.com/path/DIFFERENT/b2> <http://example.com/path/DIFFERENT/foo/bar#baz2> .
        <http://example.com/path/DIFFERENT/d3> <http://example.com/path/DIFFERENT/#b3> <http://example.com/path/DIFFERENT/e3> .
        )
        parse(ttl).should be_equivalent_graph(nt, :trace => @debug)
      end
    end
    
    describe "BNodes" do
      it "should create BNode for identifier with '_' prefix" do
        ttl = %(@prefix a: <http://foo/a#> . _:a a:p a:v .)
        nt = %(_:bnode0 <http://foo/a#p> <http://foo/a#v> .)
        parse(ttl).should be_equivalent_graph(nt, :trace => @debug)
      end
      
      it "should create BNode for [] as subject" do
        ttl = %(@prefix a: <http://foo/a#> . [] a:p a:v .)
        nt = %(_:bnode0 <http://foo/a#p> <http://foo/a#v> .)
        g = parse(ttl, :base_uri => "http://a/b")
        g.should be_equivalent_graph(nt, :about => "http://a/b", :trace => @debug)
      end
      
      it "raises error for [] as predicate" do
        ttl = %(@prefix a: <http://foo/a#> . a:s [] a:o .)
        lambda {parse(ttl)}.should raise_error RDF::ReaderError
      end
      
      it "should not create BNode for [] as predicate" do
        ttl = %(@prefix a: <http://foo/a#> . a:s [] a:o .)
        parse(ttl, :validate => false).should be_empty
      end
      
      it "should create BNode for [] as object" do
        ttl = %(@prefix a: <http://foo/a#> . a:s a:p [] .)
        nt = %(<http://foo/a#s> <http://foo/a#p> _:bnode0 .)
        parse(ttl).should be_equivalent_graph(nt, :trace => @debug)
      end
      
      it "creates BNode for [] as statement" do
        ttl = %([:a :b] .)
        nt = %(_:a <a> <b> .)
        parse(ttl, :validate => false).should be_equivalent_graph(nt, :trace => @debug)
      end
      
      it "should create BNode as a single object" do
        ttl = %q(@prefix a: <http://foo/a#> . a:b a:oneRef [ a:pp "1" ; a:qq "2" ] .)
        nt = %(
        _:a <http://foo/a#pp> "1" .
        _:a <http://foo/a#qq> "2" .
        <http://foo/a#b> <http://foo/a#oneRef> _:a .
        )
        parse(ttl, :validate => false).should be_equivalent_graph(nt, :trace => @debug)
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
        parse(ttl).should be_equivalent_graph(nt, :trace => @debug)
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
        parse(ttl).should be_equivalent_graph(nt, :trace => @debug)
      end
    end
    
    describe "objectList" do
      it "IRIs" do
        ttl = %(:a :b :c, :d)
        nt = %(
          <a> <b> <c> .
          <a> <b> <d> .
        )
        parse(ttl).should be_equivalent_graph(nt, :trace => @debug)
      end

      it "literals" do
        ttl = %(:a :b "1", "2" .)
        nt = %(
          <a> <b> "1" .
          <a> <b> "2" .
        )
        parse(ttl).should be_equivalent_graph(nt, :trace => @debug)
      end

      it "mixed" do
        ttl = %(:a :b :c, "2" .)
        nt = %(
          <a> <b> <c> .
          <a> <b> "2" .
        )
        parse(ttl).should be_equivalent_graph(nt, :trace => @debug)
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
        parse(ttl).should be_equivalent_graph(nt, :trace => @debug)
      end
    end
    
    describe "collection" do
      it "empty list" do
        ttl = %(@prefix :<http://example.com/>. :empty :set ().)
        nt = %(
        <http://example.com/empty> <http://example.com/set> <http://www.w3.org/1999/02/22-rdf-syntax-ns#nil> .)
        parse(ttl).should be_equivalent_graph(nt, :trace => @debug)
      end
      
      it "single element" do
        ttl = %(@prefix :<http://example.com/>. :gregg :wrote ("RdfContext").)
        nt = %(
        _:bnode0 <http://www.w3.org/1999/02/22-rdf-syntax-ns#first> "RdfContext" .
        _:bnode0 <http://www.w3.org/1999/02/22-rdf-syntax-ns#rest> <http://www.w3.org/1999/02/22-rdf-syntax-ns#nil> .
        <http://example.com/gregg> <http://example.com/wrote> _:bnode0 .
        )
        parse(ttl).should be_equivalent_graph(nt, :trace => @debug)
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
        parse(ttl).should be_equivalent_graph(nt, :trace => @debug)
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
        lambda {parse(ttl)}.should raise_error(RDF::ReaderError)
        parse(ttl, :validate => false).should be_equivalent_graph(nt, :trace => @debug)
      end
      
      it "adds property to nil list" do
        ttl = %(@prefix a: <http://foo/a#> . () a:prop "nilProp" .)
        nt = %(<http://www.w3.org/1999/02/22-rdf-syntax-ns#nil> <http://foo/a#prop> "nilProp" .)
        parse(ttl).should be_equivalent_graph(nt, :trace => @debug)
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
        parse(ttl).should be_equivalent_graph(nt, :trace => @debug)
      end
      
    end
  end

  describe "canonicalization" do
    {
      %("+1"^^xsd:integer) => %("1"^^<http://www.w3.org/2001/XMLSchema#integer>),
      %(+1) => %("1"^^<http://www.w3.org/2001/XMLSchema#integer>),
      %(true) => %("true"^^<http://www.w3.org/2001/XMLSchema#boolean>),
      %("lang"@EN) => %("lang"@en),
    }.each_pair do |input, result|
      it "returns object #{result} given #{input}" do
        ttl = %(@prefix xsd: <http://www.w3.org/2001/XMLSchema#> . :a :b #{input} .)
        nt = %(<a> <b> #{result} .)
        parse(ttl, :canonicalize => true).should be_equivalent_graph(nt, :trace => @debug)
      end
    end
  end
  
  describe "validation" do
    {
      %(:y :p1 "xyz"^^<http://www.w3.org/2001/XMLSchema#integer> .) => %r("xyz" is not a valid .*),
      %(:y :p1 "12xyz"^^<http://www.w3.org/2001/XMLSchema#integer> .) => %r("12xyz" is not a valid .*),
      %(:y :p1 "xy.z"^^<http://www.w3.org/2001/XMLSchema#double> .) => %r("xy\.z" is not a valid .*),
      %(:y :p1 "+1.0z"^^<http://www.w3.org/2001/XMLSchema#double> .) => %r("\+1.0z" is not a valid .*),
      %(:a :b .) =>RDF::ReaderError,
      %(:a "literal value" :b .) => RDF::ReaderError,
      %(@keywords prefix. :e prefix :f .) => RDF::ReaderError
    }.each_pair do |ttl, error|
      it "should raise '#{error}' for '#{ttl}'" do
        lambda {
          parse("@prefix xsd: <http://www.w3.org/2001/XMLSchema#> . #{ttl}", :base_uri => "http://a/b", :validate => true)
        }.should raise_error(error)
      end
    end
  end
  
  def parse(input, options = {})
    @debug = []
    graph = options[:graph] || RDF::Graph.new
    RDF::Turtle::Reader.new(input, {:debug => @debug, :validate => true, :canonicalize => false}.merge(options)).each do |statement|
      graph << statement
    end
    graph
  end
end
