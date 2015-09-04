# Spira class for manipulating test-manifest style test suites.
# Used for Turtle tests
require 'rdf/turtle'
require 'json/ld'

# For now, override RDF::Utils::File.open_file to look for the file locally before attempting to retrieve it
module RDF::Util
  module File
    REMOTE_PATH = "http://www.w3.org/2013/TurtleTests/"
    LOCAL_PATH = ::File.expand_path("../w3c-rdf", __FILE__) + '/'

    ##
    # Override to use Patron for http and https, Kernel.open otherwise.
    #
    # @param [String] filename_or_url to open
    # @param  [Hash{Symbol => Object}] options
    # @option options [Array, String] :headers
    #   HTTP Request headers.
    # @return [IO] File stream
    # @yield [IO] File stream
    def self.open_file(filename_or_url, options = {}, &block)
      case filename_or_url.to_s
      when /^file:/
        path = filename_or_url[5..-1]
        Kernel.open(path.to_s, options, &block)
      when /^#{REMOTE_PATH}/
        begin
          #puts "attempt to open #{filename_or_url} locally"
          local_filename = filename_or_url.to_s.sub(REMOTE_PATH, LOCAL_PATH)
          if ::File.exist?(local_filename)
            response = ::File.open(local_filename)
            #puts "use #{filename_or_url} locally"
            case filename_or_url.to_s
            when /\.ttl$/
              def response.content_type; 'text/turtle'; end
            when /\.nt$/
              def response.content_type; 'application/n-triples'; end
            end

            if block_given?
              begin
                yield response
              ensure
                response.close
              end
            else
              response
            end
          else
            Kernel.open(filename_or_url.to_s, options.fetch(:headers, {}), &block)
          end
        rescue Errno::ENOENT #, OpenURI::HTTPError
          # Not there, don't run tests
          StringIO.new("")
        end
      else
        Kernel.open(filename_or_url.to_s, options.fetch(:headers, {}), &block)
      end
    end
  end
end

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
          "rdft:TestNTriplesPositiveSyntax",
          "rdft:TestNTriplesNegativeSyntax",
          "rdft:TestTurtleEval",
          "rdft:TestTurtleNegativeEval"
        ]
      }
    }))
 
    class Manifest < JSON::LD::Resource
      def self.open(file)
        #puts "open: #{file}"
        prefixes = {}
        g = RDF::Repository.load(file, format:  :ttl)
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
        @input ||= RDF::Util::File.open_file(action) {|f| f.read}
      end

      def expected
        @expected ||= RDF::Util::File.open_file(result) {|f| f.read}
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