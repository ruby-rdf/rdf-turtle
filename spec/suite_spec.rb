$:.unshift "."
require 'spec_helper'

describe RDF::Turtle::Reader do
  # W3C Turtle Test suite from http://dvcs.w3.org/hg/rdf/file/default/rdf-turtle/tests/
  describe "w3c turtle tests" do
    require 'suite_helper'

    describe "positive parser tests" do
      Fixtures::TurtleTest::Good.each do |m|
        m.entries.each do |t|
          #puts t.inspect
          specify "#{t.name}: #{t.comment}" do
            # Skip tests for very long files, too long
            if %w(test-14 test-15 test-16).include?(t.name)
              pending("Skip long input file")
            elsif %w(test-29).include?(t.name)
              pending("Escapes in IRIs")
            else
              t.debug = []
              t.debug << "source:"
              t.debug << t.input.read

              reader = RDF::Turtle::Reader.new(t.input,
                  :base_uri => t.base_uri,
                  :strict => true,
                  :canonicalize => true,
                  :validate => true,
                  :debug => t.debug)

              graph = RDF::Graph.new
              begin
                graph << reader
              rescue Exception => e
                t.debug << "raised error: #{e.message}"
              end

              format = detect_format(t.output)
              output_graph = RDF::Graph.load(t.result, :format => format, :base_uri => t.inputDocument)
              graph.should be_equivalent_graph(output_graph, t)
            end
          end
        end
      end
    end

    describe "negative parser tests" do
      Fixtures::TurtleTest::Bad.each do |m|
        m.entries.each do |t|
          specify "#{t.name}: #{t.comment}" do
            t.debug = []
            t.debug << "source:"
            t.debug << t.input.read

            reader = RDF::Turtle::Reader.new(t.input,
                :base_uri => t.base_uri,
                :strict => true,
                :canonicalize => true,
                :validate => true,
                :debug => t.debug)
                
            lambda do
              graph = RDF::Graph.new << reader
            end.should raise_error(RDF::ReaderError)
          end
        end
      end
    end
  end

end