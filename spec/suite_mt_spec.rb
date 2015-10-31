$:.unshift "."
require 'spec_helper'

describe RDF::Turtle::Reader do
  # W3C RDF Semantics Test suite from https://dvcs.w3.org/hg/rdf/file/default/rdf-mt/tests/
  describe "w3c turtle tests" do
    require 'suite_helper'

    %w(manifest.ttl).each do |man|
      Fixtures::SuiteTest::Manifest.open(Fixtures::SuiteTest::MTBASE + man) do |m|
        describe m.comment do
          m.entries.each do |t|
            specify "#{t.name}: #{t.comment}" do
              t.debug = [t.inspect]
              t.debug += ["action:", t.input.read] if t.action
              t.debug += ["result:", RDF::Util::File.open_file(t.result).read] if t.result

              action_graph = t.action ? RDF::Repository.load(t.action, :base_uri => t.base) : false
              result_graph = t.result ? RDF::Repository.load(t.result:base_uri => t.base) : false

              # FIXME, graphs aren't equivalent, but action should entail result, either of which may be false
              begin
                if t.positive_test?
                  action_graph.should be_equivalent_graph(result_graph, t)
                else
                  action_graph.should be_a(RDF::Enumerable)
                end
              rescue
                if t.action == false
                  fail "don't know how to deal with false premise"
                elsif t.result == false
                  fail "don't know how to deal with false result"
                else
                  raise
                end
              end
            end
          end
        end
      end
    end
  end
end unless ENV['CI']