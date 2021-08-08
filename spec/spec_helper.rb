$:.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
$:.unshift File.dirname(__FILE__)

require "bundler/setup"
require 'rspec'
require 'rdf'
require 'rdf/ntriples'
require 'rdf/turtle'
require 'rdf/spec'
require 'rdf/spec/matchers'
require 'matchers'
begin
  require 'simplecov'
  require 'simplecov-lcov'
  require 'coveralls'
  SimpleCov::Formatter::LcovFormatter.config do |config|
    #Coveralls is coverage by default/lcov. Send info results
    config.report_with_single_file = true
    config.single_report_path = 'coverage/lcov.info'
  end

  SimpleCov.formatter = SimpleCov::Formatter::MultiFormatter.new([
    SimpleCov::Formatter::HTMLFormatter,
    SimpleCov::Formatter::LcovFormatter
  ])
  SimpleCov.start do
    add_filter "/spec/"
  end
rescue LoadError
end
require 'rdf/turtle'

module RDF
  module Isomorphic
    alias_method :==, :isomorphic_with?
  end
end

::RSpec.configure do |c|
  c.filter_run focus:  true
  c.run_all_when_everything_filtered = true
  c.exclusion_filter = {
    ruby:  lambda { |version| !(RUBY_VERSION.to_s =~ /^#{version.to_s}/) },
    not_jruby:  lambda { RUBY_PLATFORM.to_s != 'jruby'}
  }
  c.include(RDF::Spec::Matchers)
end

# Heuristically detect the input stream
def detect_format(stream)
  # Got to look into the file to see
  if stream.is_a?(IO) || stream.is_a?(StringIO)
    stream.rewind
    string = stream.read(1000)
    stream.rewind
  else
    string = stream.to_s
  end
  case string
  when /<(\w+:)?RDF/ then RDF::RDFXML::Reader
  when /<html/i   then RDF::RDFa::Reader
  when /@prefix/i then RDF::Turtle::Reader
  else                 RDF::NTriples::Reader
  end
end
