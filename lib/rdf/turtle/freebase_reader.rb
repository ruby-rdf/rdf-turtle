require 'rdf'
require 'rdf/ntriples'
require 'addressable/uri'

module RDF::Turtle
  ##
  # Parser specifically for Freebase, which has a very regular form.
  #
  # @see https://developers.google.com/freebase/data
  class FreebaseReader < RDF::NTriples::Reader
    include RDF::Turtle::Terminals

    def self.format; RDF::Turtle::Format; end

    ##
    # Extension to N-Triples reader, includes reading
    # pnames and prefixes
    def read_triple
      loop do
        readline.strip!
        line = @line
        begin
          unless blank? || read_prefix
            subject   = read_pname(:intern => true) || fail_subject
            predicate = read_pname(:intern => true) || fail_predicate
            object    = read_pname || read_uriref || read_boolean || read_literal || fail_object
            if validate? && !read_eos
              raise RDF::ReaderError, "expected end of statement in line #{lineno}: #{current_line.inspect}"
            end
            return [subject, predicate, object]
          end
        rescue RDF::ReaderError, ArgumentError, ::Addressable::URI::InvalidURIError => e
          @line = line  # this allows #read_value to work
          raise e  if validate?
        end
      end
    end

    ##
    # Read a prefix of the form `@prefix pfx: <uri> .
    #
    # Add prefix definition to `prefixes`
    # @return [RDF::URI]
    def read_prefix
      if prefix_str = match(/^@prefix\s+(\w+:\s+#{IRIREF})\s*.$/)
        prefix, iri = prefix_str.split(/:\s+/)
        return nil unless iri
        prefix(prefix, RDF::URI(iri[1..-2]))
      end
    end

    ##
    # Read a PNAME of the form `prefix:suffix`.
    # @return [RDF::URI]
    def read_pname(options = {})
      if pname_str = match(/^(#{PNAME_LN})/)
        ns, suffix = pname_str.split(':', 2)
        raise RDF::ReaderError, "prefix #{ns.inspect} is not defined" unless prefix(ns)
        prefix(ns) + suffix
      end
    end


    ##
    # Read a boolean value
    # @return [RDF::Literal::Boolean]
    def read_boolean
      if bool_str = match(/^(true|false)/)
        RDF::Literal::Boolean.new(bool_str)
      end
    end
  end # class Reader
end # module RDF::Turtle
