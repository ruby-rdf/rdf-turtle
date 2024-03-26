# Spira class for manipulating test-manifest style test suites.
# Used for Turtle tests
require 'rdf/turtle'
require 'json/ld'

# For now, override RDF::Utils::File.open_file to look for the file locally before attempting to retrieve it
module RDF::Util
  module File
    REMOTE_PATH = "https://w3c.github.io/rdf-tests/rdf/"
    LOCAL_PATH = ::File.expand_path("../rdf-tests/rdf/", __FILE__) + '/'

    class << self
      alias_method :original_open_file, :open_file
    end

    ##
    # Override to use Patron for http and https, Kernel.open otherwise.
    #
    # @param [String] filename_or_url to open
    # @param  [Hash{Symbol => Object}] options
    # @option options [Array, String] :headers
    #   HTTP Request headers.
    # @return [IO] File stream
    # @yield [IO] File stream
    def self.open_file(filename_or_url, **options, &block)
      case
      when filename_or_url.to_s =~ /^file:/
        path = filename_or_url[5..-1]
        Kernel.open(path.to_s, options, &block)
      when (filename_or_url.to_s =~ %r{^#{REMOTE_PATH}} && Dir.exist?(LOCAL_PATH))
        #puts "attempt to open #{filename_or_url} locally"
        localpath = filename_or_url.to_s.sub(REMOTE_PATH, LOCAL_PATH)
        response = begin
          ::File.open(localpath)
        rescue Errno::ENOENT => e
          raise IOError, e.message
        end
        document_options = {
          base_uri:     RDF::URI(filename_or_url),
          charset:      Encoding::UTF_8,
          code:         200,
          headers:      {}
        }
        #puts "use #{filename_or_url} locally"
        document_options[:headers][:content_type] = case filename_or_url.to_s
        when /\.ttl$/    then 'text/turtle'
        when /\.nt$/     then 'application/n-triples'
        when /\.jsonld$/ then 'application/ld+json'
        else                  'unknown'
        end

        document_options[:headers][:content_type] = response.content_type if response.respond_to?(:content_type)
        # For overriding content type from test data
        document_options[:headers][:content_type] = options[:contentType] if options[:contentType]

        remote_document = RDF::Util::File::RemoteDocument.new(response.read, **document_options)
        if block_given?
          yield remote_document
        else
          remote_document
        end
      else
        original_open_file(filename_or_url, **options, &block)
      end
    rescue IOError => e
      raise IOError, "Error opening #{filename_or_url.inspect}: #{e.message}"
    end
  end
end

module Fixtures
  module SuiteTest
    BASE = "https://w3c.github.io/rdf-tests/rdf/"
    FRAME = JSON.parse(%q({
      "@context": {
        "xsd": "http://www.w3.org/2001/XMLSchema#",
        "rdfs": "http://www.w3.org/2000/01/rdf-schema#",
        "mf": "http://www.w3.org/2001/sw/DataAccess/tests/test-manifest#",
        "mq": "http://www.w3.org/2001/sw/DataAccess/tests/test-query#",
        "rdft": "http://www.w3.org/ns/rdftest#",

        "label": "rdfs:label",
        "baseIri": {"@id": "mf:assumedTestBase", "@type": "@id"},
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
          "rdft:TestNTriplesPositiveC14N",
          "rdft:TestNTriplesNegativeC14N",
          "rdft:TestTurtleEval",
          "rdft:TestTurtleNegativeEval"
        ]
      }
    }))
 
    class Manifest < JSON::LD::Resource
      def self.open(file)
        #puts "open: #{file}"
        g = RDF::Repository.load(file, format:  :ttl)
        JSON::LD::API.fromRDF(g) do |expanded|
          JSON::LD::API.frame(expanded, FRAME) do |framed|
            yield Manifest.new(framed)
          end
        end
      end

      # @param [Hash] json framed JSON-LD
      # @return [Array<Manifest>]
      def self.from_jsonld(json)
        json['@graph'].map {|e| Manifest.new(e)}
      end

      def label
        ll = [attributes['label']] unless attributes['label'].is_a?(Array)
        l = ll.detect {|li| li.is_a?(String)}
        l ||= ll.detect {|li| li['@language'] == 'en'}
        l = l['@value'] if l.is_a?(Hash)
        l
      end

      def entries
        # Map entries to resources
        attributes['entries'].map {|e| Entry.new(e)}
      end
    end
 
    class Entry < JSON::LD::Resource
      attr_accessor :logger

      def base
        RDF::URI(@base_iri || action)
      end

      # Alias data and query
      def input
        @input ||= RDF::Util::File.open_file(action) {|f| f.read}
      end

      def expected
        @expected ||= RDF::Util::File.open_file(result) {|f| f.read} if result
      end

      def evaluate?
        Array(attributes['@type']).join(" ").match(/Eval/)
      end

      def syntax?
        !!Array(attributes['@type']).join(" ").match(/Syntax/)
      end

      def entailment?
        !!Array(attributes['@type']).join(" ").match(/Entailment/)
      end

      def ntriples?
        !!Array(attributes['@type']).join(" ").match(/NTriples/)
      end

      def positive_test?
        !Array(attributes['@type']).join(" ").match(/Negative/)
      end

      def negative_test?
        !positive_test?
      end

      def c14n?
        !!Array(attributes['@type']).join(" ").match(/C14N/)
      end

      def inspect
        super.sub('>', "\n" +
        "  syntax?: #{syntax?.inspect}\n" +
        "  positive?: #{positive_test?.inspect}\n" +
        "  evaluate?: #{evaluate?.inspect}\n" +
        "  entailment?: #{entailment?.inspect}\n" +
        ">"
      )
      end
    end
  end
end