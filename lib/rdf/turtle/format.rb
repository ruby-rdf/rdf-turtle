module RDF::Turtle
  ##
  # Turtle format specification.
  #
  # @example Obtaining an Turtle format class
  #     RDF::Format.for("etc/foaf.ttl")
  #     RDF::Format.for(:file_name      => "etc/foaf.ttl")
  #     RDF::Format.for(:file_extension => "ttl")
  #     RDF::Format.for(:content_type   => "text/turtle")
  #
  # @example Obtaining serialization format MIME types
  #     RDF::Format.content_types      #=> {"text/turtle" => [RDF::Turtle::Format]}
  #
  # @example Obtaining serialization format file extension mappings
  #     RDF::Format.file_extensions    #=> {:ttl => "text/turtle"}
  #
  # @see http://www.w3.org/TR/rdf-testcases/#ntriples
  class Format < RDF::Format
    content_type     'text/turtle',
                     extension: :ttl,
                     aliases: %w(
                       text/rdf+turtle
                       application/turtle
                       application/x-turtle
                     )
    content_encoding 'utf-8'

    reader { RDF::Turtle::Reader }
    writer { RDF::Turtle::Writer }

    ##
    # Sample detection to see if it matches Turtle (or N-Triples)
    #
    # Use a text sample to detect the format of an input file. Sub-classes implement
    # a matcher sufficient to detect probably format matches, including disambiguating
    # between other similar formats.
    #
    # @param [String] sample Beginning several bytes (~ 1K) of input.
    # @return [Boolean]
    def self.detect(sample)
      !!sample.match(%r(
        (?:@(base|prefix)) |                                            # Turtle keywords
        ["']{3} |                                                       # STRING_LITERAL_LONG_SINGLE_QUOTE/2
        "[^"]*"^^ | "[^"]*"@ |                                          # Typed/Language literals
        (?:
          (?:\s*(?:(?:<[^>]*>) | (?:\w*:\w+) | (?:"[^"]*"))\s*[,;]) ||
          (?:\s*(?:(?:<[^>]*>) | (?:\w*:\w+) | (?:"[^"]*"))){3}
        )
      )mx) && !(
        sample.match(%r([{}])) ||                                       # TriG
        sample.match(%r(@keywords|=>|\{)) ||                            # N3
        sample.match(%r(<(?:\/|html|rdf))i) ||                          # HTML, RDF/XML
        sample.match(%r(^(?:\s*<[^>]*>){4}.*\.\s*$)) ||                 # N-Quads
        sample.match(%r("@(context|subject|iri)"))                      # JSON-LD
      )
    end
  end
  
  # Alias for TTL format
  #
  # This allows the following:
  #
  # @example Obtaining an TTL format class
  #     RDF::Format.for(:ttl)         # RDF::Turtle::TTL
  #     RDF::Format.for(:ttl).reader  # RDF::Turtle::Reader
  #     RDF::Format.for(:ttl).writer  # RDF::Turtle::Writer
  class TTL < Format
    content_encoding 'utf-8'
    content_type     'text/turtle'

    reader { RDF::Turtle::Reader }
    writer { RDF::Turtle::Writer }
  end
end
