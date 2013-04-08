$:.unshift "."
require 'spec_helper'

describe RDF::Turtle::Reader do
  # W3C Turtle Test suite from https://dvcs.w3.org/hg/rdf/file/default/rdf-turtle/tests-ttl/
  describe "w3c turtle tests" do
    require 'suite_helper'

    %w(tests-ttl/manifest.ttl).each do |man|
      Fixtures::SuiteTest::Manifest.open(Fixtures::SuiteTest::BASE + man) do |m|
        describe m.comment do
          m.entries.each do |t|
            specify "#{t.name}: #{t.comment}" do
              if %w(subm-test-14 subm-test-15 subm-test-16).include?(t.name)
                pending("Skip long input file")
              elsif %w(subm-test-29).include?(t.name)
                pending("Contains illegal characters")
              elsif t.name =~ /localName_with/ && RUBY_VERSION < "1.9"
                pending("Not possible with ruby #{RUBY_VERSION}")
              else
                t.debug = [t.inspect, "source:", t.input.read]

                reader = RDF::Turtle::Reader.new(t.input,
                    :base_uri => t.base,
                    :canonicalize => false,
                    :validate => true,
                    :debug => t.debug)

                graph = RDF::Graph.new

                if t.positive_test?
                  begin
                    graph << reader
                  rescue Exception => e
                    e.message.should produce("Not exception #{e.inspect}", t.debug)
                  end

                  if t.evaluate?
                    output_graph = RDF::Graph.load(t.result, :format => :ntriples, :base_uri => t.base)
                    graph.should be_equivalent_graph(output_graph, t)
                  else
                    graph.should be_a(RDF::Enumerable)
                  end
                else
                  lambda {
                    graph << reader
                    #graph.dump(:ntriples).should produce("", t.debug)
                  }.should raise_error(RDF::ReaderError)
                end
              end
            end
          end
        end
      end
    end
  end
end unless ENV['CI']