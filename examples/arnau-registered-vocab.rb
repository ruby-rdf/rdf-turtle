#!/usr/bin/env ruby
require 'rubygems'
require 'rdf/rdfxml'
require 'rdf/turtle'

data = %q(
<?xml version="1.0" encoding="utf-8"?>
<rdf:RDF
   xmlns:owl="http://www.w3.org/2002/07/owl#"
   xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
   xmlns:vx="http://bcn.cat/data/v8y/xvcard#">
  
  <owl:Ontology rdf:about="http://bcn.cat/data/v8y/xvcard#">
  </owl:Ontology>

</rdf:RDF>)

reader = RDF::RDFXML::Reader.new(data)
graph = RDF::Graph.new << reader

puts graph.dump(:ttl, prefixes:  reader.prefixes)
