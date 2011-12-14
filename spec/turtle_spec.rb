$:.unshift "."
require 'spec_helper'

describe RDF::Turtle::Reader do
  # W3C Turtle Test suite from http://dvcs.w3.org/hg/rdf/file/default/rdf-turtle/tests/
  describe "w3c turtle tests" do
    require 'turtle_test'

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
              t.run_test do
                #t.debug = []
                g = RDF::Graph.new
                RDF::Turtle::Reader.new(t.input,
                    :base_uri => t.base_uri,
                    :strict => true,
                    :canonicalize => true,
                    :validate => true,
                    :debug => t.debug).each do |statement|
                  g << statement
                end
                g
              end
            end
          end
        end
      end
    end

    describe "negative parser tests" do
      Fixtures::TurtleTest::Bad.each do |m|
        m.entries.each do |t|
          specify "#{t.name}: #{t.comment}" do
            begin
              t.run_test do
                lambda do
                  #t.debug = []
                   g = RDF::Graph.new
                   RDF::Turtle::Reader.new(t.input,
                       :base_uri => t.base_uri,
                       :validate => true,
                       :debug => t.debug).each do |statement|
                     g << statement
                   end
                end.should raise_error(RDF::ReaderError)
              end
            end
          end
        end
      end
    end
  end

end