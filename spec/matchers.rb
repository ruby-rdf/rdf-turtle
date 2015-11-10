# coding: utf-8
require 'rdf/isomorphic'
require 'json'
JSON_STATE = JSON::State.new(
   indent:        "  ",
   space:         " ",
   space_before:  "",
   object_nl:     "\n",
   array_nl:      "\n"
 )

RSpec::Matchers.define :match_re do |expected, info|
  match do |actual|
    actual.to_s.match(expected)
  end
  
  failure_message do |actual|
    "Match failed\n" +
    "#{info[:about]}\n" +
    "Input file:\n#{info[:input]}\n" +
    "Result:\n#{actual}\n" +
    "Expression: #{expected}\n" +
    "Debug:\n#{info[:trace]}"
  end  
end
