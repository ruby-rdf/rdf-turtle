# coding: utf-8
require 'rdf/turtle/meta'
require 'ebnf/ll1/parser'

module RDF::Turtle
  ##
  # A parser for the Turtle 2
  class Reader < RDF::Reader
    format Format
    include EBNF::LL1::Parser
    include RDF::Turtle::Terminals

    # Terminals passed to lexer. Order matters!
    terminal(:ANON,                             ANON)
    terminal(:BLANK_NODE_LABEL,                 BLANK_NODE_LABEL)
    terminal(:IRIREF,                           IRIREF, unescape:  true)
    terminal(:DOUBLE,                           DOUBLE)
    terminal(:DECIMAL,                          DECIMAL)
    terminal(:INTEGER,                          INTEGER)
    terminal(:PNAME_LN,                         PNAME_LN, unescape:  true)
    terminal(:PNAME_NS,                         PNAME_NS)
    terminal(:STRING_LITERAL_LONG_SINGLE_QUOTE, STRING_LITERAL_LONG_SINGLE_QUOTE, unescape:  true)
    terminal(:STRING_LITERAL_LONG_QUOTE,        STRING_LITERAL_LONG_QUOTE,        unescape:  true)
    terminal(:STRING_LITERAL_QUOTE,             STRING_LITERAL_QUOTE,             unescape:  true)
    terminal(:STRING_LITERAL_SINGLE_QUOTE,      STRING_LITERAL_SINGLE_QUOTE,      unescape:  true)
    
    # String terminals
    terminal(nil,                               %r([\(\),.;\[\]Aa]|\^\^|true|false))

    terminal(:PREFIX,                           PREFIX)
    terminal(:BASE,                             BASE)
    terminal(:LANGTAG,                          LANGTAG)

    ##
    # Accumulated errors found during processing
    # @return [Array<String>]
    attr_reader :errors

    ##
    # Accumulated warnings found during processing
    # @return [Array<String>]
    attr_reader :warnings

    ##
    # Redirect for Freebase Reader
    #
    # @private
    def self.new(input = nil, options = {}, &block)
      klass = if options[:freebase]
        FreebaseReader
      else
        self
      end
      reader = klass.allocate
      reader.send(:initialize, input, options, &block)
      reader
    end

    ##
    # Initializes a new reader instance.
    #
    # Note, the spec does not define a default mapping for the empty prefix,
    # but it is so commonly used in examples that we define it to be the
    # empty string anyway, except when validating.
    #
    # @param  [String, #to_s]          input
    # @param  [Hash{Symbol => Object}] options
    # @option options [Hash]     :prefixes     (Hash.new)
    #   the prefix mappings to use (for acessing intermediate parser productions)
    # @option options [#to_s]    :base_uri     (nil)
    #   the base URI to use when resolving relative URIs (for acessing intermediate parser productions)
    # @option options [#to_s]    :anon_base     ("b0")
    #   Basis for generating anonymous Nodes
    # @option options [Boolean]  :validate     (false)
    #   whether to validate the parsed statements and values. If not validating,
    #   the parser will attempt to recover from errors.
    # @option options [Array] :errors
    #   array for placing errors found when parsing
    # @option options [Array] :warnings
    #   array for placing warnings found when parsing
    # @option options [Boolean] :progress
    #   Show progress of parser productions
    # @option options [Boolean, Integer, Array] :debug
    #   Detailed debug output. If set to an Integer, output is restricted
    #   to messages of that priority: `0` for errors, `1` for warnings,
    #   `2` for processor tracing, and anything else for various levels
    #   of debug. If set to an Array, information is collected in the array
    #   instead of being output to `$stderr`.
    # @option options [Boolean] :freebase (false)
    #   Use optimized Freebase reader
    # @return [RDF::Turtle::Reader]
    def initialize(input = nil, options = {}, &block)
      super do
        @options = {
          anon_base:  "b0",
          validate:  false,
          whitespace:  WS,
        }.merge(options)
        @options = {prefixes:  {nil => ""}}.merge(@options) unless @options[:validate]
        @errors = @options[:errors] || []
        @warnings = @options[:warnings] || []
        @depth = 0

        @options[:debug] ||= case
        when RDF::Turtle.debug? then true
        when @options[:progress] then 2
        when @options[:validate] then 1
        end

        @options[:base_uri] = RDF::URI(base_uri || "")
        debug("base IRI") {base_uri.inspect}
        
        debug("validate") {validate?.inspect}
        debug("canonicalize") {canonicalize?.inspect}
        debug("intern") {intern?.inspect}

        @lexer = EBNF::LL1::Lexer.new(input, self.class.patterns, @options)

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
      if block_given?
        @recovering = false
        @callback = block

        while (@lexer.first rescue @lexer.recover)
          read_statement
        end

        if validate? && !warnings.empty? && !@options[:warnings]
          $stderr.puts "Warnings: #{warnings.join("\n")}"
        end
        if validate? && !errors.empty? && !@options[:errors]
          $stderr.puts "Errors: #{errors.join("\n")}"
          raise RDF::ReaderError, "Errors found during processing"
        end
      end
      enum_for(:each_statement)
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
      if block_given?
        each_statement do |statement|
          block.call(*statement.to_triple)
        end
      end
      enum_for(:each_triple)
    end

    # add a statement, object can be literal or URI or bnode
    #
    # @param [Symbol] production
    # @param [RDF::Statement] statement the subject of the statement
    # @return [RDF::Statement] Added statement
    # @raise [RDF::ReaderError] Checks parameter types and raises if they are incorrect if parsing mode is _validate_.
    def add_statement(production, statement)
      error("Statement is invalid: #{statement.inspect.inspect}", production: produciton) if validate? && statement.invalid?
      @callback.call(statement) if statement.subject &&
                                   statement.predicate &&
                                   statement.object &&
                                   (validate? ? statement.valid? : true)
    end

    # @return [void]
    def read_statement
      error("read_statement", "Unexpected end of file") unless token = @lexer.first
      case token.type
      when :BASE, :PREFIX
        read_directive || error("Failed to parse directive", production: :directive, token: token)
      else
        read_triples || error("Expected token", production: :statement, token: token)
        token = @lexer.shift
        unless token && token.value == '.'
          error("Expected '.' following triple", production: :statement, token: token)
        end
      end
    rescue EBNF::LL1::Lexer::Error =>  e
      begin
        error("Lexer error", e.message, lineno: e.lineno, token: e.token)
      rescue SyntaxError
      end
      @lexer.recover
      # Consume until a '.' token is found to recover
      while (@lexer.first rescue @lexer.recover) && @lexer.first.value != '.'
        @lexer.shift
      end
      @lexer.shift
      @recovering = false
      @depth = 0
    rescue SyntaxError => e
      # Consume until a '.' token is found to recover
      while (@lexer.first rescue @lexer.recover) && @lexer.first.value != '.'
        begin
          @lexer.shift
        rescue EBNF::LL1::Lexer::Error
          @lexer.recover
        end
      end
      @lexer.shift
      @recovering = false
      @depth = 0
    end

    # @return [void]
    def read_directive
      depth do
        token = @lexer.shift
        progress("directive") {"token: #{token}"}
        case token.type
        when :BASE
          terminated = token.value == '@base'
          iri = @lexer.shift
          error("Expected IRIREF", :production => :base, token: iri) unless iri === :IRIREF
          @options[:base_uri] = process_iri(iri)
          error("base", "#{token} should be downcased") if token.value.start_with?('@') && token.value != '@base'

          if terminated
            error("base", "Expected #{token} to be terminated") unless @lexer.first === '.'
            @lexer.shift
          elsif @lexer.first === '.'
            error("base", "Expected #{token} not to be terminated") 
          else
            true
          end
        when :PREFIX
          pfx, iri = @lexer.shift, @lexer.shift
          terminated = token.value == '@prefix'
          error("Expected PNAME_NS", :production => :prefix, token: pfx) unless pfx === :PNAME_NS
          error("Expected IRIREF", :production => :prefix, token: iri) unless iri === :IRIREF
          debug("prefixID") {"Defined prefix #{pfx.inspect} mapping to #{iri.inspect}"}
          prefix(pfx.value[0..-2], process_iri(iri))
          error("prefixId", "#{token} should be downcased") if token.value.start_with?('@') && token.value != '@prefix'

          if terminated
            error("prefixID", "Expected #{token} to be terminated") unless @lexer.first === '.'
            @lexer.shift
          elsif @lexer.first === '.'
            error("prefixID", "Expected #{token} not to be terminated") 
          else
            true
          end
        end
      end
    end

    # @return [Object] returns the last verb matched, or subject BNode on predicateObjectList?
    def read_triples
      depth do
        error("read_triples", "Unexpected end of file") unless token = @lexer.first
        progress("triples") {"token: #{token.inspect}"}
        case token.type || token.value
        when '['
          # blankNodePropertyList predicateObjectList? 
          subject = read_blankNodePropertyList || error("Failed to parse blankNodePropertyList", production: :triples, token: token)
          read_predicateObjectList(subject) || subject
        else
          # subject predicateObjectList
          subject = read_subject || error("Failed to parse subject", production: :triples, token: token)
          read_predicateObjectList(subject) || error("Expected predicateObjectList", production: :triples, token: token)
        end
      end
    end

    # @param [RDF::Resource] subject
    # @return [RDF::URI] the last matched verb
    def read_predicateObjectList(subject)
      depth do
        last_verb = nil
        while verb = read_verb
          progress("predicateObjectList") {"verb: #{verb.inspect}"}
          last_verb = verb
          read_objectList(subject, verb) || error("Expected objectList", production: :predicateObjectList, token: @lexer.first)
          break unless @lexer.first === ';'
          @lexer.shift while @lexer.first === ';'
        end
        last_verb
      end
    end

    # @return [RDF::Term] the last matched subject
    def read_objectList(subject, predicate)
      depth do
        last_object = nil
        while object = read_object(subject, predicate)
          progress("objectList") {"object: #{object.inspect}"}
          last_object = object
          break unless @lexer.first === ','
          @lexer.shift while @lexer.first === ','
        end
        last_object
      end
    end

    # @return [RDF::URI]
    def read_verb
      error("read_verb", "Unexpected end of file") unless token = @lexer.first
      case token.type || token.value
      when 'a' then @lexer.shift && RDF.type
      else read_iri
      end
    end

    # @return [RDF::Resource]
    def read_subject
      read_iri ||
      read_BlankNode ||
      read_collection ||
      error( "Expected subject", production: :subject, token: @lexer.first)
    end

    # @return [void]
    def read_object(subject = nil, predicate = nil)
      if object = read_iri ||
        read_BlankNode ||
        read_collection ||
        read_blankNodePropertyList ||
        read_literal

        add_statement(:object, RDF::Statement(subject, predicate, object)) if subject && predicate
        object
      end
    end

    # @return [RDF::Literal]
    def read_literal
      error("read_literal", "Unexpected end of file") unless token = @lexer.first
      case token.type || token.value
      when :INTEGER then literal(@lexer.shift.value, datatype:  RDF::XSD.integer)
      when :DECIMAL
        value = @lexer.shift.value
        value = "0#{value}" if value.start_with?(".")
        literal(value, datatype:  RDF::XSD.decimal)
      when :DOUBLE  then literal(@lexer.shift.value.sub(/\.([eE])/, '.0\1'), datatype:  RDF::XSD.double)
      when "true", "false" then literal(@lexer.shift.value, datatype: RDF::XSD.boolean)
      when :STRING_LITERAL_QUOTE, :STRING_LITERAL_SINGLE_QUOTE
        value = @lexer.shift.value[1..-2]
        error("read_literal", "Unexpected end of file") unless token = @lexer.first
        case token.type || token.value
        when :LANGTAG
          literal(value, language: @lexer.shift.value[1..-1].to_sym)
        when '^^'
          @lexer.shift
          literal(value, datatype: read_iri)
        else
          literal(value)
        end
      when :STRING_LITERAL_LONG_QUOTE, :STRING_LITERAL_LONG_SINGLE_QUOTE
        value = @lexer.shift.value[3..-4]
        error("read_literal", "Unexpected end of file") unless token = @lexer.first
        case token.type || token.value
        when :LANGTAG
          literal(value, language: @lexer.shift.value[1..-1].to_sym)
        when '^^'
          @lexer.shift
          literal(value, language: read_iri)
        else
          literal(value)
        end
      end
    end

    # @return [RDF::Node]
    def read_blankNodePropertyList
      depth do
        token = @lexer.first
        if token === '['
          @lexer.shift
          progress("blankNodePropertyList") {"token: #{token.inspect}"}
          node = bnode
          read_predicateObjectList(node)
          error("blankNodePropertyList", "Expected closing ']'") unless @lexer.first === ']'
          @lexer.shift
          node
        end
      end
    end

    # @return [RDF::Node]
    def read_collection
      depth do
        if @lexer.first === '('
          @lexer.shift
          token = @lexer.first
          progress("collection") {"token: #{token.inspect}"}
          objects = []
          while object = read_object
            objects << object
          end
          list = RDF::List.new(nil, nil, objects)
          list.each_statement do |statement|
            add_statement("collection", statement)
          end
          error("collection", "Expected closing ')'") unless @lexer.first === ')'
          @lexer.shift
          list.subject
        end
      end
    end

    # @return [RDF::URI]
    def read_iri
      error("read_iri", "Unexpected end of file") unless token = @lexer.first
      case token.type
      when :IRIREF then process_iri(@lexer.shift)
      when :PNAME_LN, :PNAME_NS then pname(*@lexer.shift.value.split(':', 2))
      end
    end

    # @return [RDF::Node]
    def read_BlankNode
      error("read_BlankNode", "Unexpected end of file") unless token = @lexer.first
      case token.type
      when :BLANK_NODE_LABEL then bnode(@lexer.shift.value[2..-1])
      when :ANON then @lexer.shift && bnode
      end
    end

    # Process a URI against base
    def process_iri(iri)
      iri = iri.value[1..-2] if iri === :IRIREF
      value = RDF::URI(iri)
      value = base_uri.join(value) if value.relative?
      value.validate! if validate?
      value.canonicalize! if canonicalize?
      value = RDF::URI.intern(value) if intern?
      value
    rescue ArgumentError => e
      error("process_iri", e)
    end
    
    # Create a literal
    def literal(value, options = {})
      debug("literal") do
        "value: #{value.inspect}, " +
        "options: #{options.inspect}, " +
        "validate: #{validate?.inspect}, " +
        "c14n?: #{canonicalize?.inspect}"
      end
      RDF::Literal.new(value, options.merge(validate:  validate?, canonicalize:  canonicalize?))
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
        error("undefined prefix", production: :pname, token: prefix)
        base = ''
      end
      suffix = suffix.to_s.sub(/^\#/, "") if base.index("#")
      debug("pname") {"base: '#{base}', suffix: '#{suffix}'"}
      process_iri(base + suffix.to_s)
    end
    
    # Keep track of allocated BNodes
    def bnode(value = nil)
      return RDF::Node.new unless value
      @bnode_cache ||= {}
      @bnode_cache[value.to_s] ||= RDF::Node.new(value)
    end

  protected
    def depth
      @depth += 1
      ret = yield
      @depth -= 1
      ret
    end

    ##
    # Warning information, used as level `1` debug messages.
    #
    # @param [String] node Relevant location associated with message
    # @param [String] message Error string
    # @param [Hash] options
    # @option options [URI, #to_s] :production
    # @option options [Token] :token
    # @see {#debug}
    def warn(node, message, options = {})
      m = "WARNING "
      m += "[line: #{@lineno}] " if @lineno
      m += message
      m += " (found #{options[:token].inspect})" if options[:token]
      m += ", production = #{options[:production].inspect}" if options[:production]
      @warnings << m unless @recovering
      debug(node, m, options.merge(:level => 1))
    end

    ##
    # Error information, used as level `0` debug messages.
    #
    # @overload debug(node, message, options)
    #   @param [String] node Relevant location associated with message
    #   @param [String] message Error string
    #   @param [Hash] options
    #   @option options [URI, #to_s] :production
    #   @option options [Token] :token
    #   @see {#debug}
    def error(*args)
      return if @recovering
      options = args.last.is_a?(Hash) ? args.pop : {}
      lineno = @lineno || (options[:token].lineno if options[:token].respond_to?(:lineno))
      message = "#{args.join(': ')}"
      m = "ERROR "
      m += "[line: #{lineno}] " if lineno
      m += message
      m += " (found #{options[:token].inspect})" if options[:token]
      m += ", production = #{options[:production].inspect}" if options[:production]
      @recovering = true
      @errors << m
      debug(m, options.merge(level: 0))
      raise SyntaxError.new(m, lineno: lineno, token: options[:token], production: options[:production])
    end

    ##
    # Progress output when debugging.
    #
    # The call is ignored, unless `@options[:debug]` is set, in which
    # case it records tracing information as indicated. Additionally,
    # if `@options[:debug]` is an Integer, the call is aborted if the
    # `:level` option is less than than `:level`.
    #
    # @overload debug(node, message, options)
    #   @param [Array<String>] args Relevant location associated with message
    #   @param [Hash] options
    #   @option options [Integer] :depth
    #     Recursion depth for indenting output
    #   @option options [Integer] :level
    #     Level assigned to message, by convention, level `0` is for
    #     errors, level `1` is for warnings, level `2` is for parser
    #     progress information, and anything higher is for various levels
    #     of debug information.
    #
    # @yieldparam [:trace] trace
    # @yieldparam [Integer] level
    # @yieldparam [Integer] lineno
    # @yieldparam [Integer] depth Recursive depth of productions
    # @yieldparam [Array<String>] args
    # @yieldreturn [String] added to message
    def debug(*args)
      return unless @options[:debug]
      options = args.last.is_a?(Hash) ? args.pop : {}
      debug_level = options.fetch(:level, 3)
      return if @options[:debug].is_a?(Integer) && debug_level > @options[:debug]

      depth = options[:depth] || @depth
      args << yield if block_given?

      message = "#{args.join(': ')}"
      d_str = depth > 100 ? ' ' * 100 + '+' : ' ' * depth
      str = "[#{lineno}](#{debug_level})#{d_str}#{message}"
      case @options[:debug]
      when Array
        @options[:debug] << str
      when TrueClass
        $stderr.puts str
      when Integer
        $stderr.puts(str) if debug_level <= @options[:debug]
      end
    end

    class SyntaxError < RDF::ReaderError
      ##
      # The current production.
      #
      # @return [Symbol]
      attr_reader :production

      ##
      # The invalid token which triggered the error.
      #
      # @return [String]
      attr_reader :token

      ##
      # The line number where the error occurred.
      #
      # @return [Integer]
      attr_reader :lineno

      ##
      # Initializes a new syntax error instance.
      #
      # @param  [String, #to_s]          message
      # @param  [Hash{Symbol => Object}] options
      # @option options [Symbol]         :production  (nil)
      # @option options [String]         :token  (nil)
      # @option options [Integer]        :lineno (nil)
      def initialize(message, options = {})
        @production = options[:production]
        @token      = options[:token]
        @lineno     = options[:lineno] || (@token.lineno if @token.respond_to?(:lineno))
        super(message.to_s)
      end
    end
  end # class Reader
end # module RDF::Turtle
