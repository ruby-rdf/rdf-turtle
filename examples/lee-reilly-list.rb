#!/usr/bin/env ruby

require 'rdf'
require 'rdf/ttl'

doc = %q(
@prefix dms: <http://example.stanford.edu/ns/> .
@prefix ore: <http://www.openarchives.org/ore/terms/> .
@prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .

<http://dmstech.groups.stanford.edu/ccc001/manifest/NormalSequence> a dms:Sequence,
        ore:Aggregation,
        rdf:List;
    ore:aggregates (
      <http://example.stanford.edu/item/DOC001/fob>
      <http://example.stanford.edu/item/DOC001/fib>
      <http://example.stanford.edu/item/DOC001/iR>
      <http://example.stanford.edu/item/DOC001/iV>
      <http://example.stanford.edu/item/DOC001/iiR>
      <http://example.stanford.edu/item/DOC001/iiV>
      <http://example.stanford.edu/item/DOC001/1R>
      <http://example.stanford.edu/item/DOC001/1V>
      <http://example.stanford.edu/item/DOC001/2R>
      <http://example.stanford.edu/item/DOC001/2V>
      <http://example.stanford.edu/item/DOC001/iiiR>
      <http://example.stanford.edu/item/DOC001/iiiV>
      <http://example.stanford.edu/item/DOC001/ivR>
      <http://example.stanford.edu/item/DOC001/ivV>
      <http://example.stanford.edu/item/DOC001/bib>
      <http://example.stanford.edu/item/DOC001/bob> ) .
)

r = RDF::Turtle::Reader.new(doc)
g = RDF::Graph.new << r

puts "NTriples Representation"
puts g.dump(:ntriples)

puts "Turtle Representation"
puts g.dump(:ttl, :prefixes => r.prefixes)
