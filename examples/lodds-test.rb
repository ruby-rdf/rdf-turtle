#!/usr/bin/env ruby
#require "rubygems"
#require "bundler"
#Bundler.require(:default)
require 'rdf/turtle'
require 'rdf/ntriples'

data = "<http://example.org/doc/dataset> a <http://www.w3.org/ns/dcat#Dataset> ."
graph = RDF::Graph.new << RDF::Turtle::Reader.new( data )
puts graph.size
puts graph.dump(:ntriples)
