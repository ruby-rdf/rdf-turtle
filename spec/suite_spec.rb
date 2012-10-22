$:.unshift "."
require 'spec_helper'

describe RDF::Turtle::Reader do
  # W3C Turtle Test suite from http://dvcs.w3.org/hg/rdf/file/default/rdf-turtle/tests/
  describe "w3c turtle tests" do
    require 'suite_helper'

    %w(TurtleSubm/manifest.ttl TurtleSubm/manifest-bad.ttl Turtle/manifest.ttl ).each do |man|
      Fixtures::SuiteTest::Manifest.open(Fixtures::SuiteTest::BASE + man) do |m|
        describe m.comment do
          m.entries.each do |t|
            specify "#{t.name}: #{t.comment}" do
              if %w(test-14 test-15 test-16).include?(t.name)
                pending("Skip long input file")
              elsif %w(test-29).include?(t.name)
                pending("Escapes in IRIs")
              else
                t.debug = [t.inspect, "source:", t.input.read]

                reader = RDF::Turtle::Reader.new(t.input,
                    :base_uri => t.base,
                    :strict => true,
                    :canonicalize => true,
                    :validate => true,
                    :debug => t.debug)

                graph = RDF::Graph.new
                
                if t.positive_test?
                  begin
                    graph << reader
                  rescue Exception => e
                    e.message.should produce(nil, t.debug)
                  end
                else
                  lambda {graph << reader}.should raise_error(RDF::ReaderError)
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
  end
end unless ENV['CI']