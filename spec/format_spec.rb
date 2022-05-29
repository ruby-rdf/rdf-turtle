$:.unshift "."
require 'spec_helper'
require 'rdf/spec/format'

describe RDF::Turtle::Format do
  it_behaves_like 'an RDF::Format' do
    let(:format_class) {RDF::Turtle::Format}
  end

  describe ".for" do
    formats = [
      :turtle,
      :ttl,
      'etc/doap.ttl',
      {file_name:       'etc/doap.ttl'},
      {file_extension:  'ttl'},
      {content_type:    'text/turtle'},
      {content_type:    'application/turtle'},
      {content_type:    'application/x-turtle'},
    ].each do |arg|
      it "discovers with #{arg.inspect}" do
        expect(RDF::Format.for(arg)).to eq described_class
      end
    end

    {
      turtle:            "@prefix foo: <bar> .\n foo:a foo:b <c> .",
      STRING_LITERAL_QUOTE:   %(:a <b> 'literal' .),
      STRING_LITERAL_SINGLE_QUOTE:   %(:a <b> "literal" .),
      STRING_LITERAL_LONG_SINGLE_QUOTE:   %(:a <b> '''\nliteral\n''' .),
      STRING_LITERAL_LONG_QUOTE:   %(:a <b> """\nliteral\n""" .),
    }.each do |sym, str|
      it "detects #{sym}" do
        expect(described_class.for {str}).to eq described_class
      end
    end

    it "uses text/turtle as first content type" do
      expect(RDF::Format.for(:turtle).content_type.first).to eq "text/turtle"
    end

    it "should discover 'ttl'" do
      expect(RDF::Format.for(:ttl).reader).to eq RDF::Turtle::Reader
    end
  end

  describe "#to_sym" do
    specify {expect(described_class.to_sym).to eq :turtle}
  end

  describe "#to_uri" do
    specify {expect(described_class.to_uri).to eq RDF::URI('http://www.w3.org/ns/formats/Turtle')}
  end

  describe ".detect" do
    {
      ntriples:          "<a> <b> <c> .",
      multi_line:        '<a>\n  <b>\n  "literal"\n .',
      turtle:            "@prefix foo: <bar> .\n foo:a foo:b <c> .",
      STRING_LITERAL_QUOTE:   %(<a> <b> 'literal' .),
      STRING_LITERAL_SINGLE_QUOTE:   %(<a> <b> "literal" .),
      STRING_LITERAL_LONG_SINGLE_QUOTE:   %(<a> <b> '''\nliteral\n''' .),
      STRING_LITERAL_LONG_QUOTE:   %(<a> <b> """\nliteral\n""" .),
    }.each do |sym, str|
      it "detects #{sym}" do
        expect(described_class.detect(str)).to be_truthy
      end
    end

    {
      n3:              "@prefix foo: <bar> .\nfoo:bar = {<a> <b> <c>} .",
      nquads:  "<a> <b> <c> <d> . ",
      rdfxml:  '<rdf:RDF about="foo"></rdf:RDF>',
      jsonld:  '{"@context" => "foo"}',
      rdfa:    '<div about="foo"></div>',
      microdata:  '<div itemref="bar"></div>',
    }.each do |sym, str|
      it "does not detect #{sym}" do
        expect(described_class.detect(str)).to be_falsey
      end
    end
  end
end
