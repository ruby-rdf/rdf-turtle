$:.unshift "."
require 'spec_helper'

describe RDF::Turtle::Reader do
  # W3C Turtle Test suite from http://www.w3.org/2013/TurtleTests/manifest.ttl
  describe "w3c turtle tests" do
    require 'suite_helper'

    Fixtures::SuiteTest::Manifest.open("http://www.w3.org/2013/TurtleTests/manifest.ttl") do |m|
      describe m.comment do
        m.entries.each do |t|
          specify "#{t.name}: #{t.comment}" do
            t.debug = [t.inspect, "source:", t.input]
            t.warnings = []
            t.errors = []

            reader = RDF::Turtle::Reader.new(t.input,
                base_uri:  t.base,
                canonicalize:  false,
                validate:  true,
                debug:  t.debug)

            graph = RDF::Repository.new

            if t.positive_test?
              begin
                graph << reader
              rescue Exception => e
                expect(e.message).to produce("Not exception #{e.inspect}", t)
              end

              if t.evaluate?
                output_graph = RDF::Repository.load(t.result, format:  :ntriples, base_uri:  t.base)
                expect(graph).to be_equivalent_graph(output_graph, t)
              else
                expect(graph).to be_a(RDF::Enumerable)
              end
            else
              expect {
                graph << reader
                expect(graph.dump(:ntriples)).to produce("not this", t)
              }.to raise_error(RDF::ReaderError)
            end
          end
        end
      end
    end
  end
end unless ENV['CI']