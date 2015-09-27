$:.unshift "."
require 'spec_helper'
require 'rdf/spec/writer'

describe RDF::Turtle::Writer do
  before(:each) {$stderr, @old_stderr = StringIO.new, $stderr}
  after(:each) {$stderr = @old_stderr}

  it_behaves_like 'an RDF::Writer' do
    let(:writer) {RDF::Turtle::Writer.new}
  end

  subject {described_class.new}

  describe ".for" do
    [
      :turtle,
      'etc/doap.ttl',
      {file_name:       'etc/doap.ttl'},
      {file_extension:  'ttl'},
      {content_type:    'text/turtle'},
      {content_type:    'application/turtle'},
      {content_type:    'application/x-turtle'},
    ].each do |arg|
      it "discovers with #{arg.inspect}" do
        expect(RDF::Writer.for(arg)).to eq RDF::Turtle::Writer
      end
    end
  end

  describe "simple tests" do
    it "should use full URIs without base" do
      input = %(<http://a/b> <http://a/c> <http://a/d> .)
      serialize(input, nil, [%r(^<http://a/b> <http://a/c> <http://a/d> \.$)])
    end

    it "should use relative URIs with base" do
      input = %(<http://a/b> <http://a/c> <http://a/d> .)
      serialize(input, "http://a/",
       [ %r(^@base <http://a/> \.$),
        %r(^<b> <c> <d> \.$)]
      )
    end

    it "should use pname URIs with prefix" do
      input = %(<http://xmlns.com/foaf/0.1/b> <http://xmlns.com/foaf/0.1/c> <http://xmlns.com/foaf/0.1/d> .)
      serialize(input, nil,
        [%r(^@prefix foaf: <http://xmlns.com/foaf/0.1/> \.$),
        %r(^foaf:b foaf:c foaf:d \.$)],
        prefixes: { foaf: RDF::FOAF}
      )
    end

    it "should use pname URIs with empty prefix" do
      input = %(<http://xmlns.com/foaf/0.1/b> <http://xmlns.com/foaf/0.1/c> <http://xmlns.com/foaf/0.1/d> .)
      serialize(input, nil,
        [%r(^@prefix : <http://xmlns.com/foaf/0.1/> \.$),
        %r(^:b :c :d \.$)],
        prefixes: { "" => RDF::FOAF}
      )
    end
    
    # see example-files/arnau-registered-vocab.rb
    it "should use pname URIs with empty suffix" do
      input = %(<http://xmlns.com/foaf/0.1/> <http://xmlns.com/foaf/0.1/> <http://xmlns.com/foaf/0.1/> .)
      serialize(input, nil,
        [%r(^@prefix foaf: <http://xmlns.com/foaf/0.1/> \.$),
        %r(^foaf: foaf: foaf: \.$)],
        prefixes: { "foaf" => RDF::FOAF}
      )
    end
    
    it "should order properties" do
      input = %(
        @prefix : <http://xmlns.com/foaf/0.1/> .
        @prefix dc: <http://purl.org/dc/elements/1.1/> .
        @prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#> .
        :b :c :d .
        :b dc:title "title" .
        :b a :class .
        :b rdfs:label "label" .
      )
      serialize(input, nil,
        [
          %r(^:b a :class;$),
          %r(:class;\s+rdfs:label "label")m,
          %r("label";\s+dc:title "title")m,
          %r("title";\s+:c :d \.$)m
        ],
        prefixes: { "" => RDF::FOAF, dc:  "http://purl.org/dc/elements/1.1/", rdfs:  RDF::RDFS}
      )
    end
    
    it "should generate object list" do
      input = %(@prefix : <http://xmlns.com/foaf/0.1/> . :b :c :d, :e .)
      serialize(input, nil,
        [%r(^@prefix : <http://xmlns.com/foaf/0.1/> \.$),
        %r(^:b :c :d,$),
        %r(^\s+:e \.$)],
        prefixes: { "" => RDF::FOAF}
      )
    end
    
    it "should generate property list" do
      input = %(@prefix : <http://xmlns.com/foaf/0.1/> . :b :c :d; :e :f .)
      serialize(input, nil,
        [%r(^@prefix : <http://xmlns.com/foaf/0.1/> \.$),
        %r(^:b :c :d;$),
        %r(^\s+:e :f \.$)],
        prefixes: { "" => RDF::FOAF}
      )
    end
  end
  
  describe "anons" do
    it "should generate bare anon" do
      input = %(@prefix : <http://xmlns.com/foaf/0.1/> . [:a :b] .)
      serialize(input, nil,
        [%r(^\s*\[ :a :b\] \.$)],
        prefixes: { "" => RDF::FOAF}
      )
    end
    
    it "should generate anon as subject" do
      input = %(@prefix : <http://xmlns.com/foaf/0.1/> . [:a :b] :c :d .)
      serialize(input, nil,
        [%r(^\s*\[\s*:a :b;$)m,
        %r(^\s+:c :d\s*\] \.$)m],
        prefixes: { "" => RDF::FOAF}
      )
    end
    
    it "should generate anon as object" do
      input = %(@prefix : <http://xmlns.com/foaf/0.1/> . :a :b [:c :d] .)
      serialize(input, nil,
        [%r(^\s*\:a :b \[ :c :d\] \.$)],
        prefixes: { "" => RDF::FOAF}
      )
    end
  end

  describe "BNodes" do
    let(:input) {%(@prefix : <http://xmlns.com/foaf/0.1/> . _:a :b _:a .)}
    it "reuses BNode labels by default" do
      serialize(input, nil,
        [%r(^\s*_:a :b _:a \.$)],
        prefixes: { "" => RDF::FOAF}
      )
    end
    it "uses generated BNodes with :unique_bnodes" do
      serialize(input, nil,
        [%r(^\s*_:g\w+ :b _:g\w+ \.$)],
        prefixes: { "" => RDF::FOAF},
        unique_bnodes: true
      )
    end
  end

  describe "lists" do
    it "should generate bare list" do
      input = %(@prefix : <http://xmlns.com/foaf/0.1/> . (:a :b) .)
      serialize(input, nil,
        [%r(^\(:a :b\) \.$)],
        prefixes: { "" => RDF::FOAF}
      )
    end

    it "should generate literal list" do
      input = %(@prefix : <http://xmlns.com/foaf/0.1/> . :a :b ( "apple" "banana" ) .)
      serialize(input, nil,
        [%r(^:a :b \("apple" "banana"\) \.$)],
        prefixes: { "" => RDF::FOAF}
      )
    end
    
    it "should generate empty list" do
      input = %(@prefix : <http://xmlns.com/foaf/0.1/> . :a :b () .)
      serialize(input, nil,
        [%r(^:a :b \(\) \.$)],
        prefixes: { "" => RDF::FOAF}
      )
    end
    
    it "should generate empty list as subject" do
      input = %(@prefix : <http://xmlns.com/foaf/0.1/> . () :a :b .)
      serialize(input, nil,
        [%r(^\(\) :a :b \.$)],
        prefixes: { "" => RDF::FOAF}
      )
    end
    
    it "should generate list as subject" do
      input = %(@prefix : <http://xmlns.com/foaf/0.1/> . (:a) :b :c .)
      serialize(input, nil,
        [%r(^\(:a\) :b :c \.$)],
        prefixes: { "" => RDF::FOAF}
      )
    end

    it "should generate list of empties" do
      input = %(@prefix : <http://xmlns.com/foaf/0.1/> . [:listOf2Empties (() ())] .)
      serialize(input, nil,
        [%r(\[ :listOf2Empties \(\(\) \(\)\)\] \.$)],
        prefixes: { "" => RDF::FOAF}
      )
    end
    
    it "should generate list anon" do
      input = %(@prefix : <http://xmlns.com/foaf/0.1/> . [:twoAnons ([a :mother] [a :father])] .)
      serialize(input, nil,
        [%r(\[ :twoAnons \(\[ a :mother\] \[ a :father\]\)\] \.$)],
        prefixes: { "" => RDF::FOAF}
      )
    end
    
    it "should generate owl:unionOf list" do
      input = %(
        @prefix : <http://xmlns.com/foaf/0.1/> .
        @prefix owl: <http://www.w3.org/2002/07/owl#> .
        @prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
        @prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#> .
        :a rdfs:domain [
          a owl:Class;
          owl:unionOf [
            a owl:Class;
            rdf:first :b;
            rdf:rest [
              a owl:Class;
              rdf:first :c;
              rdf:rest rdf:nil
            ]
          ]
        ] .
      )
      #$verbose = true
      serialize(input, nil,
        [
          %r(:a rdfs:domain \[\s+a owl:Class;\s+owl:unionOf\s+\(:b\s+:c\)\s*\]\s*\.$)m,
          %r(@prefix : <http://xmlns.com/foaf/0.1/> \.),
          %r(@prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> \.),
        ],
        prefixes: { "" => RDF::FOAF, rdfs:  RDF::RDFS, owl:  RDF::OWL, rdf:  "http://www.w3.org/1999/02/22-rdf-syntax-ns#"}
      )
      #$verbose = false
    end
  end

  describe "literals" do
    describe "plain" do
      it "encodes embedded \"\"\"" do
        ttl = %(:a :b """testing string parsing in Turtle.
                """ .)
        serialize(ttl, nil, [/testing string parsing in Turtle.\n/])
      end

      it "encodes embedded \"" do
        ttl = %(:a :b """string with " escaped quote marks""" .)
        serialize(ttl, nil, [/string with \\" escaped quote mark/])
      end
    end
    
    describe "with language" do
      it "specifies language for literal with language" do
        ttl = %q(:a :b "string"@en .)
        serialize(ttl, nil, [%r("string"@en)])
      end
    end
    
    describe "xsd:anyURI" do
      it "uses xsd namespace for datatype" do
        ttl = %q(@prefix xsd: <http://www.w3.org/2001/XMLSchema#> . :a :b "http://foo/"^^xsd:anyURI .)
        serialize(ttl, nil, [
          %r(@prefix xsd: <http://www.w3.org/2001/XMLSchema#> \.),
          %r("http://foo/"\^\^xsd:anyURI \.),
        ])
      end
    end
    
    describe "xsd:boolean" do
      [
        [%q("true"^^xsd:boolean), /true ./],
        [%q("TrUe"^^xsd:boolean), /true ./],
        [%q("1"^^xsd:boolean), /true ./],
        [%q(true), /true ./],
        [%q("false"^^xsd:boolean), /false ./],
        [%q("FaLsE"^^xsd:boolean), /false ./],
        [%q("0"^^xsd:boolean), /false ./],
        [%q(false), /false ./],
      ].each do |(l,r)|
        it "uses token for #{l.inspect}" do
          ttl = %(@prefix xsd: <http://www.w3.org/2001/XMLSchema#> . :a :b #{l} .)
          serialize(ttl, nil, [
            %r(@prefix xsd: <http://www.w3.org/2001/XMLSchema#> \.),
            r,
          ], canonicalize: true)
        end
      end

      [
        [true, "true"],
        [false, "false"],
        [1, "true"],
        [0, "false"],
        ["true", "true"],
        ["false", "false"],
        ["1", "true"],
        ["0", "false"],
        ["string", %{"string"^^<http://www.w3.org/2001/XMLSchema#boolean>}],
      ].each do |(l,r)|
        it "serializes #{l.inspect} to #{r.inspect}" do
          expect(subject.format_literal(RDF::Literal::Boolean.new(l))).to eql r
        end
      end

      context "without literal shorthand" do
        subject {described_class.new($stdout, literal_shorthand: false)}
        [
          [true, %{"true"^^<http://www.w3.org/2001/XMLSchema#boolean>}],
          [false, %{"false"^^<http://www.w3.org/2001/XMLSchema#boolean>}],
          [1, %{"true"^^<http://www.w3.org/2001/XMLSchema#boolean>}],
          [0,  %{"false"^^<http://www.w3.org/2001/XMLSchema#boolean>}],
          ["true", %{"true"^^<http://www.w3.org/2001/XMLSchema#boolean>}],
          ["false",  %{"false"^^<http://www.w3.org/2001/XMLSchema#boolean>}],
          ["1", %{"1"^^<http://www.w3.org/2001/XMLSchema#boolean>}],
          ["0",  %{"0"^^<http://www.w3.org/2001/XMLSchema#boolean>}],
          ["string", %{"string"^^<http://www.w3.org/2001/XMLSchema#boolean>}],
        ].each do |(l,r)|
          it "serializes #{l.inspect} to #{r.inspect}" do
            expect(subject.format_literal(RDF::Literal::Boolean.new(l))).to eql r
          end
        end
      end
    end
    
    describe "xsd:integer" do
      [
        [%q("1"^^xsd:integer), /1 ./],
        [%q(1), /1 ./],
        [%q("0"^^xsd:integer), /0 ./],
        [%q(0), /0 ./],
        [%q("10"^^xsd:integer), /10 ./],
        [%q(10), /10 ./],
      ].each do |(l,r)|
        it "uses token for #{l.inspect}" do
          ttl = %(@prefix xsd: <http://www.w3.org/2001/XMLSchema#> . :a :b #{l} .)
          serialize(ttl, nil, [
            %r(@prefix xsd: <http://www.w3.org/2001/XMLSchema#> \.),
            r,
          ], canonicalize: true)
        end
      end

      [
        [0, "0"],
        [10, "10"],
        [-1, "-1"],
        ["0", "0"],
        ["true", %{"true"^^<http://www.w3.org/2001/XMLSchema#integer>}],
        ["false", %{"false"^^<http://www.w3.org/2001/XMLSchema#integer>}],
        ["string", %{"string"^^<http://www.w3.org/2001/XMLSchema#integer>}],
      ].each do |(l,r)|
        it "serializes #{l.inspect} to #{r.inspect}" do
          expect(subject.format_literal(RDF::Literal::Integer.new(l))).to eql r
        end
      end

      context "without literal shorthand" do
        subject {described_class.new($stdout, literal_shorthand: false)}
        [
          [0, %{"0"^^<http://www.w3.org/2001/XMLSchema#integer>}],
          [10, %{"10"^^<http://www.w3.org/2001/XMLSchema#integer>}],
          [-1, %{"-1"^^<http://www.w3.org/2001/XMLSchema#integer>}],
          ["0", %{"0"^^<http://www.w3.org/2001/XMLSchema#integer>}],
          ["true", %{"true"^^<http://www.w3.org/2001/XMLSchema#integer>}],
          ["false", %{"false"^^<http://www.w3.org/2001/XMLSchema#integer>}],
          ["string", %{"string"^^<http://www.w3.org/2001/XMLSchema#integer>}],
        ].each do |(l,r)|
          it "serializes #{l.inspect} to #{r.inspect}" do
            expect(subject.format_literal(RDF::Literal::Integer.new(l))).to eql r
          end
        end
      end
    end

    describe "xsd:int" do
      [
        [%q("1"^^xsd:int), /"1"\^\^xsd:int ./],
        [%q("0"^^xsd:int), /"0"\^\^xsd:int ./],
        [%q("10"^^xsd:int), /"10"\^\^xsd:int ./],
      ].each do |(l,r)|
        it "uses token for #{l.inspect}" do
          ttl = %(@prefix xsd: <http://www.w3.org/2001/XMLSchema#> . :a :b #{l} .)
          serialize(ttl, nil, [
            %r(@prefix xsd: <http://www.w3.org/2001/XMLSchema#> \.),
            r,
          ], canonicalize: true)
        end
      end
    end

    describe "xsd:decimal" do
      [
        [%q("1.0"^^xsd:decimal), /1.0 ./],
        [%q(1.0), /1.0 ./],
        [%q("0.1"^^xsd:decimal), /0.1 ./],
        [%q(0.1), /0.1 ./],
        [%q("10.02"^^xsd:decimal), /10.02 ./],
        [%q(10.02), /10.02 ./],
      ].each do |(l,r)|
        it "uses token for #{l.inspect}" do
          ttl = %(@prefix xsd: <http://www.w3.org/2001/XMLSchema#> . :a :b #{l} .)
          serialize(ttl, nil, [
            %r(@prefix xsd: <http://www.w3.org/2001/XMLSchema#> \.),
            r,
          ], canonicalize: true)
        end
      end

      [
        [0, "0.0"],
        [10, "10.0"],
        [-1, "-1.0"],
        ["0", "0.0"],
        ["10", "10.0"],
        ["-1", "-1.0"],
        ["1.0", "1.0"],
        ["0.1", "0.1"],
        ["10.01", "10.01"],
        ["true", %{"true"^^<http://www.w3.org/2001/XMLSchema#decimal>}],
        ["false", %{"false"^^<http://www.w3.org/2001/XMLSchema#decimal>}],
        ["string", %{"string"^^<http://www.w3.org/2001/XMLSchema#decimal>}],
      ].each do |(l,r)|
        it "serializes #{l.inspect} to #{r.inspect}" do
          expect(subject.format_literal(RDF::Literal::Decimal.new(l))).to eql r
        end
      end

      context "without literal shorthand" do
        subject {described_class.new($stdout, literal_shorthand: false)}
        [
          [0, %{"0.0"^^<http://www.w3.org/2001/XMLSchema#decimal>}],
          [10, %{"10.0"^^<http://www.w3.org/2001/XMLSchema#decimal>}],
          [-1, %{"-1.0"^^<http://www.w3.org/2001/XMLSchema#decimal>}],
          ["0", %{"0"^^<http://www.w3.org/2001/XMLSchema#decimal>}],
          ["10", %{"10"^^<http://www.w3.org/2001/XMLSchema#decimal>}],
          ["-1", %{"-1"^^<http://www.w3.org/2001/XMLSchema#decimal>}],
          ["1.0", %{"1.0"^^<http://www.w3.org/2001/XMLSchema#decimal>}],
          ["0.1", %{"0.1"^^<http://www.w3.org/2001/XMLSchema#decimal>}],
          ["10.01", %{"10.01"^^<http://www.w3.org/2001/XMLSchema#decimal>}],
        ].each do |(l,r)|
          it "serializes #{l.inspect} to #{r.inspect}" do
            expect(subject.format_literal(RDF::Literal::Decimal.new(l))).to eql r
          end
        end
      end
    end
    
    describe "xsd:double" do
      [
        [%q("1.0e1"^^xsd:double), /1.0e1 ./],
        [%q(1.0e1), /1.0e1 ./],
        [%q("0.1e1"^^xsd:double), /1.0e0 ./],
        [%q(0.1e1), /1.0e0 ./],
        [%q("10.02e1"^^xsd:double), /1.002e2 ./],
        [%q(10.02e1), /1.002e2 ./],
        [%q("14"^^xsd:double), /1.4e1 ./],
      ].each do |(l,r)|
        it "uses token for #{l.inspect}" do
          ttl = %(@prefix xsd: <http://www.w3.org/2001/XMLSchema#> . :a :b #{l} .)
          serialize(ttl, nil, [
            %r(@prefix xsd: <http://www.w3.org/2001/XMLSchema#> \.),
            r,
          ], canonicalize: true)
        end
      end
    end

    [
      [0, "0.0e0"],
      [10, "1.0e1"],
      [-1, "-1.0e0"],
      ["0", "0.0e0"],
      ["10", "1.0e1"],
      ["-1", "-1.0e0"],
      ["1.0", "1.0e0"],
      ["0.1", "1.0e-1"],
      ["10.01", "1.001e1"],
      ["true", %{"true"^^<http://www.w3.org/2001/XMLSchema#double>}],
      ["false", %{"false"^^<http://www.w3.org/2001/XMLSchema#double>}],
      ["string", %{"string"^^<http://www.w3.org/2001/XMLSchema#double>}],
    ].each do |(l,r)|
      it "serializes #{l.inspect} to #{r.inspect}" do
        expect(subject.format_literal(RDF::Literal::Double.new(l))).to eql r
      end
    end

    context "without literal shorthand" do
      subject {described_class.new($stdout, literal_shorthand: false)}
      [
        [0, %{"0.0"^^<http://www.w3.org/2001/XMLSchema#double>}],
        [10, %{"10.0"^^<http://www.w3.org/2001/XMLSchema#double>}],
        [-1, %{"-1.0"^^<http://www.w3.org/2001/XMLSchema#double>}],
        ["0", %{"0"^^<http://www.w3.org/2001/XMLSchema#double>}],
        ["10", %{"10"^^<http://www.w3.org/2001/XMLSchema#double>}],
        ["-1", %{"-1"^^<http://www.w3.org/2001/XMLSchema#double>}],
        ["1.0", %{"1.0"^^<http://www.w3.org/2001/XMLSchema#double>}],
        ["0.1", %{"0.1"^^<http://www.w3.org/2001/XMLSchema#double>}],
        ["10.01", %{"10.01"^^<http://www.w3.org/2001/XMLSchema#double>}],
      ].each do |(l,r)|
        it "serializes #{l.inspect} to #{r.inspect}" do
          expect(subject.format_literal(RDF::Literal::Double.new(l))).to eql r
        end
      end
    end
  end
  
  # W3C Turtle Test suite from http://www.w3.org/TR/turtle/tests/
  describe "w3c turtle tests" do
    require 'suite_helper'

    %w(manifest.ttl).each do |man|
      Fixtures::SuiteTest::Manifest.open(Fixtures::SuiteTest::BASE + man) do |m|
        describe m.comment do
          m.entries.each do |t|
            next unless t.positive_test? && t.evaluate?
            specify "#{t.name}: #{t.comment}" do
              pending("native literals canonicalized") if t.name == "turtle-subm-26"
              graph = parse(t.expected, format: :ntriples)
              ttl = serialize(graph, t.base, [], format: :ttl, base_uri: t.base, standard_prefixes: true)
              @debug += [t.inspect, "source:", t.expected]
              g2 = parse(ttl, base_uri: t.base)
              expect(g2).to be_equivalent_graph(graph, debug: @debug.join("\n"))
            end

            specify "#{t.name}: #{t.comment} (stream)" do
              pending("native literals canonicalized") if t.name == "turtle-subm-26"
              graph = parse(t.expected, format: :ntriples)
              ttl = serialize(graph, t.base, [], stream: true, format: :ttl, base_uri: t.base, standard_prefixes: true)
              @debug += [t.inspect, "source:", t.expected]
              g2 = parse(ttl, base_uri: t.base)
              expect(g2).to be_equivalent_graph(graph, debug: @debug.join("\n"))
            end
          end
        end
      end
    end
  end unless ENV['CI'] # Not for continuous integration

  def parse(input, options = {})
    graph = RDF::Graph.new
    RDF::Turtle::Reader.new(input, options).each do |statement|
      graph << statement
    end
    graph
  end

  # Serialize ntstr to a string and compare against regexps
  def serialize(ntstr, base = nil, regexps = [], options = {})
    prefixes = options[:prefixes] || {nil => ""}
    g = ntstr.is_a?(RDF::Enumerable) ? ntstr : parse(ntstr, base_uri: base, prefixes: prefixes, validate: false)
    @debug = ["serialized:", ntstr]
    result = RDF::Turtle::Writer.buffer(options.merge(
      debug: @debug,
      base_uri: base,
      prefixes: prefixes,
      encoding: Encoding::UTF_8,
    )) do |writer|
      writer << g
    end
    
    regexps.each do |re|
      expect(result).to match_re(re, about: base, debug: @debug, input: ntstr)
    end
    
    result
  end
end