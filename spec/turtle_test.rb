# Spira class for manipulating test-manifest style test suites.
# Used for Turtle tests
require 'spira'
require 'rdf/turtle'
require 'open-uri'

module Fixtures
  module TurtleTest
    class MF < RDF::Vocabulary("http://www.w3.org/2001/sw/DataAccess/tests/test-manifest#"); end

    class Entry
      attr_accessor :debug
      attr_accessor :compare
      include Spira::Resource
      type MF["Entry"]

      property :name, :predicate => MF["name"], :type => XSD.string
      property :comment, :predicate => RDF::RDFS.comment, :type => XSD.string
      property :result, :predicate => MF.result
      has_many :action, :predicate => MF["action"]

      def input
        Kernel.open(self.inputDocument)
      end
      
      def output
        self.result ? Kernel.open(self.result) : ""
      end

      def inputDocument
        self.class.repository.first_object(:subject => self.action.first)
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

      # Run test case, yields input for parser to create triples
      def run_test(options = {})
        # Run
        graph = yield
        
        return unless self.result

        case self.compare
        when :none
          # Don't check output, just parse to graph
        when :array
          @parser.graph.should be_equivalent_graph(self.output, self)
        else
          #puts "parse #{self.outputDocument} as #{RDF::Reader.for(self.outputDocument)}"
          format = detect_format(self.output)
          output_graph = RDF::Graph.load(self.result, :format => format, :base_uri => self.inputDocument)
          puts "result: #{CGI.escapeHTML(graph.to_ntriples)}" if ::RDF::Turtle::debug?
          graph.should Matchers::be_equivalent_graph(output_graph, self)
        end
      end
    end

    class Good < Entry
      default_source :turtle
    end
    
    class Bad < Entry
      default_source :turtle_bad
    end
    
    turtle = RDF::Repository.load("http://www.w3.org/2001/sw/DataAccess/df1/tests/manifest.ttl")

    # Add types to entries
    turtle.subjects(:predicate => MF["action"]).each do |s|
      turtle << RDF::Statement.new(s, RDF.type, MF["Entry"])
    end

    Spira.add_repository! :turtle, turtle
    
    turtle_bad = RDF::Repository.load("http://www.w3.org/2001/sw/DataAccess/df1/tests/manifest-bad.ttl")

    # Add types to entries
    turtle_bad.subjects(:predicate => MF["action"]).each do |s|
      turtle_bad << RDF::Statement.new(s, RDF.type, MF["Entry"])
    end

    Spira.add_repository! :turtle_bad, turtle_bad
    
  end
end