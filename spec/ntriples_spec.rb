$:.unshift "."
require 'spec_helper'

describe RDF::NTriples::Reader do
  # W3C N-Triples Test suite from https://dvcs.w3.org/hg/rdf/file/default/rdf-turtle/tests-nt/
  describe "w3c N-Triples tests" do
    require 'suite_helper'

    %w(manifest.ttl).each do |man|
      Fixtures::SuiteTest::Manifest.open(Fixtures::SuiteTest::NTBASE + man) do |m|
        describe m.comment do
          m.entries.each do |t|
            specify "#{t.name}: #{t.comment}" do
              t.debug = [t.inspect, "source:", t.input.read]

              reader = RDF::NTriples::Reader.new(t.input,
                  :validate => true)

              graph = RDF::Graph.new

              if t.positive_test?
                begin
                  graph << reader
                rescue Exception => e
                  e.message.should produce("Not exception #{e.inspect}", t.debug)
                end
              else
                lambda {
                  graph << reader
                  #graph.dump(:ntriples).should produce("", t.debug)
                }.should raise_error
              end

              if t.evaluate?
                output_graph = RDF::Graph.load(t.result, :format => :ntriples, :base_uri => t.base)
                graph.should be_equivalent_graph(output_graph, t)
              else
                graph.should be_a(RDF::Enumerable)
              end
            end
          end
        end
      end
    end
  end
end unless ENV['CI']