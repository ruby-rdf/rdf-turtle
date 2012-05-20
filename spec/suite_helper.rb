# Spira class for manipulating test-manifest style test suites.
# Used for Turtle tests
require 'spira'
require 'rdf/turtle'
require 'rdf/n3'    # XXX only needed because the manifest is currently returned as text/n3, not text/ttl
require 'open-uri'

module Fixtures
  module TurtleTest
    BASE_URI = "http://dvcs.w3.org/hg/rdf/raw-file/default/rdf-turtle/tests"
    class MF < RDF::Vocabulary("http://www.w3.org/2001/sw/DataAccess/tests/test-manifest#"); end

    class Manifest < Spira::Base
      type MF.Manifest
      property :entry_list, :predicate => MF['entries']
      property :comment,    :predicate => RDFS.comment
    end

    class Entry
      attr_accessor :debug
      attr_accessor :compare
      include Spira::Resource
      type MF["Entry"]

      property :name,     :predicate => MF["name"],         :type => XSD.string
      property :comment,  :predicate => RDF::RDFS.comment,  :type => XSD.string
      property :result,   :predicate => MF.result
      has_many :action,   :predicate => MF["action"]

      def input
        Kernel.open(self.inputDocument)
      end
      
      def output
        self.result ? Kernel.open(self.result) : ""
      end

      def inputDocument
        self.class.repository.first_object(:subject => self.action.first)
      end

      def base_uri
        inputDocument.to_s.sub(BASE_URI, 'http://www.w3.org/2001/sw/DataAccess/df1/tests')
      end
      
      def inspect
        "[#{self.class.to_s} " + %w(
          subject
          name
          comment
          result
          inputDocument
        ).map {|a| v = self.send(a); "#{a}='#{v}'" if v}.compact.join(", ") +
        "]"
      end
    end

    class Good < Manifest
      default_source :turtle

      def entries
        RDF::List.new(entry_list, self.class.repository).map { |entry| entry.as(GoodEntry) }
      end
    end
    
    class Bad < Manifest
      default_source :turtle_bad

      def entries
        RDF::List.new(entry_list, self.class.repository).map { |entry| entry.as(BadEntry) }
      end
    end

    class GoodEntry < Entry
      default_source :turtle
    end

    class BadEntry < Entry
      default_source :turtle_bad
    end

    # Note that the texts README says to use a different base URI
    turtle = RDF::Repository.load("#{BASE_URI}/manifest.ttl", :format => :ttl)
    Spira.add_repository! :turtle, turtle
    
    turtle_bad = RDF::Repository.load("#{BASE_URI}/manifest-bad.ttl", :format => :ttl)
    Spira.add_repository! :turtle_bad, turtle_bad
  end
end