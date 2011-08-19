require 'rdf'

class RDF::Literal::String
  ##
  # RDF 1.1 and Turtle define that all plain literals are the same as having datatype xsd:string.
  # However, the xsd:string should not be serialized
  def has_datatype?; false; end
end