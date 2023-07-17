$:.unshift "."
require 'spec_helper'

describe RDF::NTriples::Reader do
  # W3C N-Triples Test suite from https://dvcs.w3.org/hg/rdf/file/default/rdf-turtle/tests-nt/
  describe "w3c N-Triples tests" do
    require 'suite_helper'

    %w(rdf11/rdf-n-triples/manifest.ttl).each do |man|
      Fixtures::SuiteTest::Manifest.open(Fixtures::SuiteTest::BASE + man) do |m|
        describe m.comment do
          m.entries.each do |t|
            specify "#{t.name}: #{t.comment}" do
              t.logger = RDF::Spec.logger
              t.logger.info t.inspect
              t.logger.info "source:\n#{t.input}"

              reader = RDF::NTriples::Reader.new(t.input,
                logger: t.logger,
                validate:  true)

              graph = RDF::Graph.new

              if t.positive_test?
                begin
                  graph << reader
                rescue Exception => e
                  expect(e.message).to produce("Not exception #{e.inspect}", t.logger)
                end
              else
                expect {
                  graph << reader
                  #expect(graph.dump(:ntriples).should produce("", t.debug)
                }.to raise_error RDF::ReaderError
              end

              if t.evaluate?
                output_graph = RDF::Graph.load(t.result, format:  :ntriples, base_uri:  t.base)
                expect(graph).to be_equivalent_graph(output_graph, t)
              else
                expect(graph).to be_a(RDF::Enumerable)
              end
            end
          end
        end
      end
    end
  end
end unless ENV['CI']