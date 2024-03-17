gem "rdf"
gem "rdf-turtle"
require "rdf/turtle"
ttl = '@prefix p: <http://a.example/>. p:a\/a <http://a.example/p> <http://a.example/o> .'
rdf=RDF::Turtle::Reader.new(ttl) {|reader|
  p reader.statements
}