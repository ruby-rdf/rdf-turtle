require 'rdf/turtle/meta'
require 'rdf/ll1/parser'

module RDF::Turtle
  ##
  # A parser for the Turtle 2
  class Reader < RDF::Reader
    format Format
    include RDF::Turtle::Meta
    include RDF::LL1::Parser
    include RDF::Turtle::Terminals

    # Terminals passed to lexer. Order matters!
    terminal(:ANON,                 ANON) do |reader, prod, token, input|
      input[:resource] = reader.bnode
    end
    terminal(:BLANK_NODE_LABEL,     BLANK_NODE_LABEL) do |reader, prod, token, input|
      input[:resource] = reader.bnode(token.value[2..-1])
    end
    terminal(:IRI_REF,              IRI_REF, :unescape => true) do |reader, prod, token, input|
      input[:resource] = reader.process_iri(token.value[1..-2])
    end
    terminal(:DOUBLE,               DOUBLE) do |reader, prod, token, input|
      input[:resource] = reader.literal(token.value, :datatype => RDF::XSD.double)
    end
    terminal(:DOUBLE_NEGATIVE,      DOUBLE_NEGATIVE) do |reader, prod, token, input|
      input[:resource] = reader.literal(token.value, :datatype => RDF::XSD.double)
    end
    terminal(:DOUBLE_POSITIVE,      DOUBLE_POSITIVE) do |reader, prod, token, input|
      input[:resource] = reader.literal(token.value, :datatype => RDF::XSD.double)
    end
    terminal(:DECIMAL,              DECIMAL) do |reader, prod, token, input|
      input[:resource] = reader.literal(token.value, :datatype => RDF::XSD.decimal)
    end
    terminal(:DECIMAL_NEGATIVE,     DECIMAL_NEGATIVE) do |reader, prod, token, input|
      input[:resource] = reader.literal(token.value, :datatype => RDF::XSD.decimal)
    end
    terminal(:DECIMAL_POSITIVE,     DECIMAL_POSITIVE) do |reader, prod, token, input|
      input[:resource] = reader.literal(token.value, :datatype => RDF::XSD.decimal)
    end
    terminal(:INTEGER,              INTEGER) do |reader, prod, token, input|
      input[:resource] = reader.literal(token.value, :datatype => RDF::XSD.integer)
    end
    terminal(:INTEGER_NEGATIVE,     INTEGER_NEGATIVE) do |reader, prod, token, input|
      input[:resource] = reader.literal(token.value, :datatype => RDF::XSD.integer)
    end
    terminal(:INTEGER_POSITIVE,     INTEGER_POSITIVE) do |reader, prod, token, input|
      input[:resource] = reader.literal(token.value, :datatype => RDF::XSD.integer)
    end
    # Spec confusion: spec says : "Literals , prefixed names and IRIs may also contain escape sequences"
    terminal(:PNAME_LN,             PNAME_LN) do |reader, prod, token, input|
      prefix, suffix = token.value.split(":", 2)
      input[:resource] = reader.pname(prefix, suffix)
    end
    # Spec confusion: spec says : "Literals , prefixed names and IRIs may also contain escape sequences"
    terminal(:PNAME_NS,             PNAME_NS) do |reader, prod, token, input|
      prefix = token.value[0..-2]
      
      # Two contexts, one when prefix is being defined, the other when being used
      case prod
      when :prefixID
        input[:prefix] = prefix
      else
        input[:resource] = reader.pname(prefix, '')
      end
    end
    terminal(:STRING_LITERAL_LONG1, STRING_LITERAL_LONG1, :unescape => true) do |reader, prod, token, input|
      input[:string_value] = token.value[3..-4]
    end
    terminal(:STRING_LITERAL_LONG2, STRING_LITERAL_LONG2, :unescape => true) do |reader, prod, token, input|
      input[:string_value] = token.value[3..-4]
    end
    terminal(:STRING_LITERAL1,      STRING_LITERAL1, :unescape => true) do |reader, prod, token, input|
      input[:string_value] = token.value[1..-2]
    end
    terminal(:STRING_LITERAL2,      STRING_LITERAL2, :unescape => true) do |reader, prod, token, input|
      input[:string_value] = token.value[1..-2]
    end
    
    # String terminals
    terminal(nil,                  %r([\(\),.;\[\]a]|\^\^|@base|@prefix|true|false)) do |reader, prod, token, input|
      case token.value
      when 'a'             then input[:resource] = RDF.type
      when 'true', 'false' then input[:resource] = RDF::Literal::Boolean.new(token.value)
      else                      input[:string] = token.value
      end
    end
    terminal(:LANGTAG,              LANGTAG) do |reader, prod, token, input|
      input[:lang] = token.value[1..-1]
    end

    # Productions
    
    # [4] prefixID defines a prefix mapping
    production(:prefixID) do |reader, phase, input, current, callback|
      next unless phase == :finish
      prefix = current[:prefix]
      iri = current[:resource]
      callback.call(:trace, "prefixID", "Defined prefix #{prefix.inspect} mapping to #{iri.inspect}")
      reader.prefix(prefix, iri)
    end
    
    # [5] base set base_uri
    production(:base) do |reader, phase, input, current, callback|
      next unless phase == :finish
      iri = current[:resource]
      callback.call(:trace, "base", "Defined base as #{iri}")
      reader.options[:base_uri] = iri
    end
    
    # [9] verb ::= predicate | "a"
    production(:verb) do |reader, phase, input, current, callback|
      next unless phase == :finish
      input[:predicate] = current[:resource] if phase == :finish
    end

    # [10] subject ::= IRIref | blank
    production(:subject) do |reader, phase, input, current, callback|
      next unless phase == :finish
      input[:subject] = current[:resource] if phase == :finish
    end

    # [12] object ::= IRIref | blank | literal
    production(:object) do |reader, phase, input, current, callback|
      next unless phase == :finish
      if input[:object_list]
        # Part of an rdf:List collection
        input[:object_list] << current[:resource]
      else
        callback.call(:trace, "object", "current: #{current.inspect}")
        callback.call(:statement, "object", input[:subject], input[:predicate], current[:resource])
      end
    end

    # [15] blankNodePropertyList ::= "[" predicateObjectList "]"
    production(:blankNodePropertyList) do |reader, phase, input, current, callback|
      if phase == :start
        current[:subject] = reader.bnode
      else
        input[:resource] = current[:subject]
      end
    end
    
    # [16] collection ::= "(" object* ")"
    production(:collection) do |reader, phase, input, current, callback|
      if phase == :start
        current[:object_list] = []  # Tells the object production to collect and not generate statements
      else
        # Create an RDF list
        bnode = reader.bnode
        objects = current[:object_list]
        list = RDF::List.new(bnode, nil, objects)
        list.each_statement do |statement|
          # Spec Confusion, referenced section "Collection" is missing from the spec.
          # Anicdodal evidence indicates that some expect each node to be of type rdf:list,
          # but existing Notation3 and Turtle tests (http://www.w3.org/2001/sw/DataAccess/df1/tests/manifest.ttl) do not.
          next if statement.predicate == RDF.type && statement.object == RDF.List
          callback.call(:statement, "collection", statement.subject, statement.predicate, statement.object)
        end
        bnode = RDF.nil if list.empty?

        # Return bnode as resource
        input[:resource] = bnode
      end
    end
    
    # [60s] RDFLiteral ::= String ( LANGTAG | ( "^^" IRIref ) )? 
    production(:RDFLiteral) do |reader, phase, input, current, callback|
      next unless phase == :finish
      opts = {}
      opts[:datatype] = current[:resource] if current[:resource]
      opts[:language] = current[:lang] if current[:lang]
      input[:resource] = reader.literal(current[:string_value], opts)
    end

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
    #   whether to validate the parsed statements and values. If not validating,
    #   the parser will attempt to recover from errors.
    # @option options [Boolean] :progress
    #   Show progress of parser productions
    # @option options [Boolean] :debug
    #   Detailed debug output
    # @return [RDF::Turtle::Reader]
    def initialize(input = nil, options = {}, &block)
      super do
        @options = {:anon_base => "b0", :validate => false}.merge(options)

        debug("def prefix", "#{base_uri.inspect}")
        
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

      parse(@input, START.to_sym, @options.merge(:branch => BRANCH, :follow => FOLLOW)) do |context, *data|
        case context
        when :statement
          add_triple(*data)
        when :trace
          debug(*data)
        end
      end
    rescue RDF::LL1::Parser::Error => e
      error("each_statement", e.message, :backtrace => e.backtrace)
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

    # add a statement, object can be literal or URI or bnode
    #
    # @param [Nokogiri::XML::Node, any] node:: XML Node or string for showing context
    # @param [URI, Node] subject:: the subject of the statement
    # @param [URI] predicate:: the predicate of the statement
    # @param [URI, Node, Literal] object:: the object of the statement
    # @return [Statement]:: Added statement
    # @raise [RDF::ReaderError]:: Checks parameter types and raises if they are incorrect if parsing mode is _validate_.
    def add_triple(node, subject, predicate, object)
      statement = RDF::Statement.new(subject, predicate, object)
      if statement.valid?
        debug(node, "generate statement: #{statement}")
        @callback.call(statement)
      else
        error(node, "Statement is invalid: #{statement.inspect}")
      end
    end

    def process_iri(iri)
      iri(base_uri, iri)
    end
    
    # Create IRIs
    def iri(value, append = nil)
      value = RDF::URI.new(value)
      value = value.join(append) if append
      value.validate! if validate? && value.respond_to?(:validate)
      value.canonicalize! if canonicalize?
      value = RDF::URI.intern(value) if intern?
      value
    end

    # Create a literal
    def literal(value, options = {})
      options = options.dup
      # Internal representation is to not use xsd:string, although it could arguably go the other way.
      options.delete(:datatype) if options[:datatype] == RDF::XSD.string
      debug("literal", "value: #{value.inspect}, options: #{options.inspect}, validate: #{validate?.inspect}, c14n?: #{canonicalize?.inspect}")
      RDF::Literal.new(value, options.merge(:validate => validate?, :canonicalize => canonicalize?))
    end

    ##
    # Override #prefix to take a relative IRI
    #
    # prefix directives map a local name to an IRI, also resolved against the current In-Scope Base URI.
    # Spec confusion, presume that an undefined empty prefix has an empty relative IRI, which uses
    # string contatnation rules against the in-scope IRI at the time of use
    def prefix(prefix, iri = nil)
      # Relative IRIs are resolved against @base
      iri = process_iri(iri) if iri
      super(prefix, iri)
    end
    
    ##
    # Expand a PNAME using string concatenation
    def pname(prefix, suffix)
      # Prefixes must be defined, except special case for empty prefix being alias for current @base
      if prefix(prefix)
        base = prefix(prefix).to_s
      elsif !prefix(prefix)
        error("pname", "undefined prefix #{prefix.inspect}")
        base = ''
      end
      suffix = suffix.to_s.sub(/^\#/, "") if base.index("#")
      debug("pname", "base: '#{base}', suffix: '#{suffix}'")
      process_iri(base + suffix.to_s)
    end
    
    # Keep track of allocated BNodes
    def bnode(value = nil)
      return RDF::Node.new unless value
      @bnode_cache ||= {}
      @bnode_cache[value.to_s] ||= RDF::Node.new(value)
    end

    # @param [String] str Error string
    # @param [Hash] options
    # @option options [URI, #to_s] :production
    # @option options [Token] :token
    def error(node, message, options = {})
      if !validate? && !options[:fatal]
        debug(node, message, options)
      else
        raise RDF::ReaderError, message, options[:backtrace]
      end
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
