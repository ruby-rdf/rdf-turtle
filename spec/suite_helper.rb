# Spira class for manipulating test-manifest style test suites.
# Used for Turtle tests
require 'rdf/turtle'
require 'json/ld'

module Fixtures
  module SuiteTest
    BASE = "http://www.w3.org/2013/TurtleTests/"
    NTBASE = "https://dvcs.w3.org/hg/rdf/raw-file/default/rdf-turtle/tests-nt/"
    FRAME = JSON.parse(%q({
      "@context": {
        "xsd": "http://www.w3.org/2001/XMLSchema#",
        "rdfs": "http://www.w3.org/2000/01/rdf-schema#",
        "mf": "http://www.w3.org/2001/sw/DataAccess/tests/test-manifest#",
        "mq": "http://www.w3.org/2001/sw/DataAccess/tests/test-query#",
        "rdft": "http://www.w3.org/ns/rdftest#",
    
        "comment": "rdfs:comment",
        "entries": {"@id": "mf:entries", "@container": "@list"},
        "name": "mf:name",
        "action": {"@id": "mf:action", "@type": "@id"},
        "result": {"@id": "mf:result", "@type": "@id"}
      },
      "@type": "mf:Manifest",
      "entries": {
        "@type": [
          "rdft:TestTurtlePositiveSyntax",
          "rdft:TestTurtleNegativeSyntax",
          "rdft:TestTurtleEval",
          "rdft:TestTurtleNegativeEval"
        ]
      }
    }))
 
    class Manifest < JSON::LD::Resource
      def self.open(file)
        #puts "open: #{file}"
        prefixes = {}
        g = RDF::Repository.load(file, :format => :turtle)
        JSON::LD::API.fromRDF(g) do |expanded|
          JSON::LD::API.frame(expanded, FRAME) do |framed|
            yield Manifest.new(framed['@graph'].first)
          end
        end
      end

      # @param [Hash] json framed JSON-LD
      # @return [Array<Manifest>]
      def self.from_jsonld(json)
        json['@graph'].map {|e| Manifest.new(e)}
      end

      def entries
        # Map entries to resources
        attributes['entries'].map {|e| Entry.new(e)}
      end
    end
 
    class Entry < JSON::LD::Resource
      attr_accessor :debug

      def base
        BASE + action.split('/').last
      end

      # Alias data and query
      def input
        RDF::Util::File.open_file(action)
      end

      def expected
        RDF::Util::File.open_file(result)
      end
      
      def evaluate?
        Array(attributes['@type']).join(" ").match(/Eval/)
      end
      
      def syntax?
        Array(attributes['@type']).join(" ").match(/Syntax/)
      end

      def positive_test?
        !Array(attributes['@type']).join(" ").match(/Negative/)
      end
      
      def negative_test?
        !positive_test?
      end
      
      def inspect
        super.sub('>', "\n" +
        "  syntax?: #{syntax?.inspect}\n" +
        "  positive?: #{positive_test?.inspect}\n" +
        "  evaluate?: #{evaluate?.inspect}\n" +
        ">"
      )
      end
    end
  end
end