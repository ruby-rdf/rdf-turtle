require 'rdf'

class RDF::Literal::String
  ##
  # RDF 1.1 and Turtle define that all plain literals are the same as having datatype xsd:string.
  # However, the xsd:string should not be serialized
  def has_datatype?; false; end
end

module RDF
  class List
    ##
    # Validate the list ensuring that
    # * rdf:rest values are all BNodes are nil
    # * rdf:type, if it exists, is rdf:List
    # * each subject has no properties other than single-valued rdf:first, rdf:rest
    #   other than for the first node in the list
    # @return [Boolean]
    def valid?
      li = subject
      while li != RDF.nil do
        rest = nil
        firsts = rests = 0
        @graph.query(:subject => li) do |st|
          case st.predicate
          when RDF.type
            # Be tollerant about rdf:type entries, as some OWL vocabularies use it excessively
          when RDF.first
            firsts += 1
          when RDF.rest
            rest = st.object
            return false unless rest.node? || rest == RDF.nil
            rests += 1
          else
            # First node may have other properties
            return false unless li == subject
          end
        end
        return false unless firsts == 1 && rests == 1
        li = rest
      end
      true
    end
  end
end
