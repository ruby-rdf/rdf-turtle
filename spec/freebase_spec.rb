# coding: utf-8
$:.unshift "."
require 'spec_helper'
require 'rdf/spec/reader'

describe "RDF::Turtle::FreebaseReader" do
  let!(:prefixes) {
    %q(
      @prefix ns: <http://rdf.freebase.com/ns/>.
      @prefix key: <http://rdf.freebase.com/key/>.
      @prefix owl: <http://www.w3.org/2002/07/owl#>.
      @prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#>.
      @prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>.
      @prefix xsd: <http://www.w3.org/2001/XMLSchema#>.
    )
  }

  before :each do
    @reader = RDF::Turtle::FreebaseReader.new(StringIO.new(""))
  end

  context :interface do
    subject {
      %q(
        @prefix foo: <bar> .
        foo:a foo:b "baz" .
        foo:c foo:d <foobar> .
      )
    }
    
    it "should yield reader" do
      inner = double("inner")
      expect(inner).to receive(:called).with(RDF::Turtle::FreebaseReader)
      RDF::Turtle::FreebaseReader.new(subject) do |reader|
        inner.called(reader.class)
      end
    end
    
    it "should return reader" do
      expect(RDF::Turtle::FreebaseReader.new(subject)).to be_a(RDF::Turtle::FreebaseReader)
    end
    
    it "should not raise errors" do
      expect {
        RDF::Turtle::FreebaseReader.new(subject, validate:  true)
      }.not_to raise_error
    end

    it "should yield statements" do
      inner = double("inner")
      expect(inner).to receive(:called).with(RDF::Statement).exactly(2)
      RDF::Turtle::FreebaseReader.new(subject).each_statement do |statement|
        inner.called(statement.class)
      end
    end
    
    it "should yield triples" do
      inner = double("inner")
      expect(inner).to receive(:called).exactly(2)
      RDF::Turtle::FreebaseReader.new(subject).each_triple do |subject, predicate, object|
        inner.called(subject.class, predicate.class, object.class)
      end
    end
  end

  describe "#prefix" do
    let!(:input) {
      %q(
        foo:a foo:b "baz" .
        foo:c foo:d <foobar> .
      )
    }
    subject {RDF::Turtle::FreebaseReader.new(input, prefixes:  {foo:  "http://example/bar#"})}
    it "should have prefix :foo" do
      expect(subject.prefix(:foo)).to eq "http://example/bar#"
    end
    it "should have prefix 'foo'" do
      expect(subject.prefix('foo')).to eq "http://example/bar#"
    end
    its(:prefixes) {should have_key(:foo)}

    it "should parse equivalent to Turtle:Reader" do
      g = RDF::Graph.new << subject
      expect(g).to be_equivalent_graph("@prefix foo: <http://example/bar#> ." + input, logger: @logger)
    end
  end

  describe "with simple sample data" do
    {
      qname:       %q(ns:m.012rkqx    ns:type.object.type ns:common.topic.),
      langString:  %q(ns:m.012rkqx    ns:type.object.name "High Fidelity"@en.),
      string:      %q(ns:m.012rkqx    key:authority.musicbrainz   "258c45bd-4437-4580-8988-b3f3be975f9c".),
      boolean:     %q(ns:american_football.football_historical_roster_position.number ns:type.property.unique true .),
      iri:         %q(ns:g.1hhc3t8lm ns:common.licensed_object.attribution_uri <http://data.worldbank.org/indicator/IS.VEH.NVEH.P3> .),
      numeric:     %q(ns:g.11_plx64m ns:measurement_unit.dated_percentage.rate 9.2 .),
      date:        %q(ns:m.012rkqx    ns:film.film.initial_release_date    "2012-08-31"^^xsd:datetime .),
    }.each do |name, input|
      it name do
        ttl = prefixes + "\n" + input
        
        expect(parse(ttl)).to be_equivalent_graph(ttl, logger: @logger)
      end
    end
  end

  describe "literal forms" do
    [
      %(ns:a ns:b true .),
      %(ns:a ns:b false .)  ,
      %(ns:a ns:b 1 .),
      %(ns:a ns:b -1 .),
      %(ns:a ns:b +1 .),
      %(ns:a ns:b .1 .),
      %(ns:a ns:b 1.0 .),
      %(ns:a ns:b 1.0e1 .),
      %(ns:a ns:b 1.0e-1 .),
      %(ns:a ns:b 1.0e+1 .),
      %(ns:a ns:b 1.0E1 .),
      %(ns:a ns:b 123.E+1 .),
    ].each do |input|
      it "should create typed literal for '#{input}'" do
        ttl = prefixes + "\n" + input
        
        expect(parse(ttl)).to be_equivalent_graph(ttl, logger: @logger)
      end
    end
  end

  describe "validation" do
    {
      %("lit" <b> <c> .) => %r(Expected subject),
      %(ns:a "lit" <c> .) => %r(Expected predicate),
      %(undef:a ns:b "c") => %r(prefix "undef" is not defined),
    }.each_pair do |ttl, error|
      it "should raise '#{error}' for '#{ttl}'" do
        expect {
          input = prefixes + "\n" + ttl
          expect(parse(input, validate:  true)).to produce("", logger: @logger)
        }.to raise_error(error)
      end
    end
  end

  def parse(input, options = {})
    @logger = RDF::Spec.logger
    options = {
      logger: @logger,
      validate:  true,
      canonicalize:  false,
    }.merge(options)
    graph = options[:graph] || RDF::Graph.new
    RDF::Turtle::FreebaseReader.new(input, options).each do |statement|
      graph << statement
    end
    graph
  end
end
