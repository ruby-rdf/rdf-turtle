module RDF::Turtle
  ##
  # RDFa format specification.
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
    content_type     'text/turtle',         :extension => :ttl
    content_type     'text/rdf+turtle'
    content_type     'application/turtle'
    content_type     'application/x-turtle'
    content_encoding 'utf-8'

    reader { RDF::Turtle::Reader }
    writer { RDF::Turtle::Writer }
  end
  
  # Alias for TTL format
  #
  # This allows the following:
  #
  # @example Obtaining an TTL format class
  #     RDF::Format.for(:ttl)         # RDF::Turtle::TTL
  #     RDF::Format.for(:ttl).reader  # RDF::Turtle::Reader
  #     RDF::Format.for(:ttl).writer  # RDF::Turtle::Writer
  class TTL < RDF::Format
    reader { RDF::Turtle::Reader }
    writer { RDF::Turtle::Writer }
  end
end
