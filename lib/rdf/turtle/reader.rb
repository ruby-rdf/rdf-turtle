require 'rdf/turtle/meta'
require 'rdf/ll1/parser'

module RDF::Turtle
  ##
  # A parser for the Turtle 2
  class Reader < RDF::Reader
    format Format
    include RDF::Turtle::Meta
    include RDF::LL1::Parser
    include RDF::Turtle::Tokens

    # Tokens passed to lexer. Order matters!
    terminal :ANON,                 ANON
    terminal :BLANK_NODE_LABEL,     BLANK_NODE_LABEL
    terminal :IRI_REF,              IRI_REF
    terminal :DOUBLE,               DOUBLE
    terminal :DOUBLE_NEGATIVE,      DOUBLE_NEGATIVE
    terminal :DOUBLE_POSITIVE,      DOUBLE_POSITIVE
    terminal :DECIMAL,              DECIMAL
    terminal :DECIMAL_NEGATIVE,     DECIMAL_NEGATIVE
    terminal :DECIMAL_POSITIVE,     DECIMAL_POSITIVE
    terminal :INTEGER,              INTEGER
    terminal :INTEGER_NEGATIVE,     INTEGER_NEGATIVE
    terminal :INTEGER_POSITIVE,     INTEGER_POSITIVE
    terminal :PNAME_LN,             PNAME_LN
    terminal :PNAME_NS,             PNAME_NS
    terminal :STRING_LITERAL_LONG1, STRING_LITERAL_LONG1
    terminal :STRING_LITERAL_LONG2, STRING_LITERAL_LONG2
    terminal :STRING_LITERAL1,      STRING_LITERAL1
    terminal :STRING_LITERAL2,      STRING_LITERAL2
    terminal nil,                  %r([\(\),.;\[\]a]|\^\^|@base|@prefix|true|false)
    terminal :LANGTAG,              LANGTAG

    ##
    # Missing in 0.3.2
    def base_uri
      @options[:base_uri]
    end

    ##
    # Initializes a new parser instance.
    #
    # @param  [String, #to_s]          input
    # @param  [Hash{Symbol => Object}] options
    # @option options [Hash]     :prefixes     (Hash.new)
    #   the prefix mappings to use (for acessing intermediate parser productions)
    # @option options [#to_s]    :base_uri     (nil)
    #   the base URI to use when resolving relative URIs (for acessing intermediate parser productions)
    # @option options [#to_s]    :anon_base     ("b0")
    #   Basis for generating anonymous Nodes
    # @option options [Boolean] :resolve_uris (false)
    #   Resolve prefix and relative IRIs, otherwise, when serializing the parsed SSE
    #   as S-Expressions, use the original prefixed and relative URIs along with `base` and `prefix`
    #   definitions.
    # @option options [Boolean]  :validate     (false)
    #   whether to validate the parsed statements and values
    # @option options [Boolean] :progress
    #   Show progress of parser productions
    # @option options [Boolean] :debug
    #   Detailed debug output
    # @return [RDF::Turtle::Reader]
    def initialize(input = nil, options = {}, &block)
      super do
        @options = {:anon_base => "b0", :validate => false}.merge(options)

        debug("validate", "#{validate?.inspect}")
        debug("canonicalize", "#{canonicalize?.inspect}")
        debug("intern", "#{intern?.inspect}")

        if block_given?
          case block.arity
            when 0 then instance_eval(&block)
            else block.call(self)
          end
        end
      end
    end

    def inspect
      sprintf("#<%s:%#0x(%s)>", self.class.name, __id__, base_uri.to_s)
    end

    ##
    # Iterates the given block for each RDF statement in the input.
    #
    # @yield  [statement]
    # @yieldparam [RDF::Statement] statement
    # @return [void]
    def each_statement(&block)
      @callback = block

      parse(@input, START.to_sym, @options.merge(:branch => BRANCH)) do |context, *data|
        case context
        when :statement
          block.call(*data)
        when :trace
          debug(*data)
        end
      end
    rescue RDF::LL1::Parser::Error => e
      raise RDF::ReaderError, e.message
    end
    
    ##
    # Iterates the given block for each RDF triple in the input.
    #
    # @yield  [subject, predicate, object]
    # @yieldparam [RDF::Resource] subject
    # @yieldparam [RDF::URI]      predicate
    # @yieldparam [RDF::Value]    object
    # @return [void]
    def each_triple(&block)
      each_statement do |statement|
        block.call(*statement.to_triple)
      end
    end

  private

    # Create URIs
    def uri(value)
      # If we have a base URI, use that when constructing a new URI
      uri = if self.base_uri
        u = self.base_uri.join(value.to_s)
        u.lexical = "<#{value}>" unless u.to_s == value.to_s || options[:resolve_uris]
        u
      else
        RDF::URI(value)
      end

      #uri.validate! if validate? && uri.respond_to?(:validate)
      #uri.canonicalize! if canonicalize?
      #uri = RDF::URI.intern(uri) if intern?
      uri
    end

    def namespace(prefix, uri)
      uri = uri.to_s
      if uri == '#'
        uri = prefix(nil).to_s + '#'
      end
      debug("namespace", "'#{prefix}' <#{uri}>")
      prefix(prefix, uri(uri))
    end
    
    def ns(prefix, suffix)
      base = prefix(prefix).to_s
      suffix = suffix.to_s.sub(/^\#/, "") if base.index("#")
      debug("ns(#{prefix.inspect})", "base: '#{base}', suffix: '#{suffix}'")
      uri = uri(base + suffix.to_s)
      # Cause URI to be serialized as a lexical
      uri.lexical = "#{prefix}:#{suffix}" unless options[:resolve_uris]
      uri
    end
    
    # Keep track of allocated BNodes
    def bnode(value = nil)
      @bnode_cache ||= {}
      @bnode_cache[value.to_s] ||= RDF::Node.new(value)
    end

    ##
    # Progress output when debugging
    # @param [String] str
    def debug(node, message, options = {})
      depth = options[:depth] || self.depth
      str = "[#{@lineno}]#{' ' * depth}#{node}: #{message}"
      @options[:debug] << str if @options[:debug].is_a?(Array)
      $stderr.puts(str) if RDF::Turtle.debug?
    end
  end # class Reader
end # module RDF::Turtle
