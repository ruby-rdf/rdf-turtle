require 'rdf/turtle/meta'
require 'ebnf/ll1/parser'

module RDF::Turtle
  ##
  # A parser for the Turtle 2
  class Reader < RDF::Reader
    format Format
    include RDF::Turtle::Meta
    include EBNF::LL1::Parser
    include RDF::Turtle::Terminals

    # Terminals passed to lexer. Order matters!
    terminal(:ANON,                 ANON) do |prod, token, input|
      input[:resource] = self.bnode
    end
    terminal(:BLANK_NODE_LABEL,     BLANK_NODE_LABEL) do |prod, token, input|
      input[:resource] = self.bnode(token.value[2..-1])
    end
    terminal(:IRIREF,               IRIREF, unescape:  true) do |prod, token, input|
      input[:resource] = process_iri(token.value[1..-2])
    end
    terminal(:DOUBLE,               DOUBLE) do |prod, token, input|
      # Note that a Turtle Double may begin with a '.[eE]', so tack on a leading
      # zero if necessary
      value = token.value.sub(/\.([eE])/, '.0\1')
      input[:resource] = literal(value, datatype:  RDF::XSD.double)
    end
    terminal(:DECIMAL,              DECIMAL) do |prod, token, input|
      # Note that a Turtle Decimal may begin with a '.', so tack on a leading
      # zero if necessary
      value = token.value
      value = "0#{token.value}" if token.value[0,1] == "."
      input[:resource] = literal(value, datatype:  RDF::XSD.decimal)
    end
    terminal(:INTEGER,              INTEGER) do |prod, token, input|
      input[:resource] = literal(token.value, datatype:  RDF::XSD.integer)
    end
    # Spec confusion: spec says : "Literals , prefixed names and IRIs may also contain escape sequences"
    terminal(:PNAME_LN,             PNAME_LN, unescape:  true) do |prod, token, input|
      prefix, suffix = token.value.split(":", 2)
      input[:resource] = pname(prefix, suffix)
    end
    # Spec confusion: spec says : "Literals , prefixed names and IRIs may also contain escape sequences"
    terminal(:PNAME_NS,             PNAME_NS) do |prod, token, input|
      prefix = token.value[0..-2]
      
      # Two contexts, one when prefix is being defined, the other when being used
      case prod
      when :prefixID, :sparqlPrefix
        input[:prefix] = prefix
      else
        input[:resource] = pname(prefix, '')
      end
    end
    terminal(:STRING_LITERAL_LONG_SINGLE_QUOTE, STRING_LITERAL_LONG_SINGLE_QUOTE, unescape:  true) do |prod, token, input|
      input[:string_value] = token.value[3..-4]
    end
    terminal(:STRING_LITERAL_LONG_QUOTE, STRING_LITERAL_LONG_QUOTE, unescape:  true) do |prod, token, input|
      input[:string_value] = token.value[3..-4]
    end
    terminal(:STRING_LITERAL_QUOTE,      STRING_LITERAL_QUOTE, unescape:  true) do |prod, token, input|
      input[:string_value] = token.value[1..-2]
    end
    terminal(:STRING_LITERAL_SINGLE_QUOTE,      STRING_LITERAL_SINGLE_QUOTE, unescape:  true) do |prod, token, input|
      input[:string_value] = token.value[1..-2]
    end
    
    # String terminals
    terminal(nil,                  %r([\(\),.;\[\]Aa]|\^\^|true|false)) do |prod, token, input|
      case token.value
      when 'A', 'a'           then input[:resource] = RDF.type
      when 'true', 'false'    then input[:resource] = RDF::Literal::Boolean.new(token.value)
      when '@base', '@prefix' then input[:lang] = token.value[1..-1]
      when '.'                then input[:terminated] = true
      else                         input[:string] = token.value
      end
    end

    terminal(:PREFIX,      PREFIX) do |prod, token, input|
      input[:string_value] = token.value
    end
    terminal(:BASE,      BASE) do |prod, token, input|
      input[:string_value] = token.value
    end

    terminal(:LANGTAG,              LANGTAG) do |prod, token, input|
      input[:lang] = token.value[1..-1]
    end

    # Productions
    # [4] prefixID defines a prefix mapping
    production(:prefixID) do |input, current, callback|
      prefix = current[:prefix]
      iri = current[:resource]
      lexical = current[:string_value]
      terminated = current[:terminated]
      debug("prefixID") {"Defined prefix #{prefix.inspect} mapping to #{iri.inspect}"}
      if lexical.start_with?('@') && lexical != '@prefix'
        error(:prefixID, "should be downcased")
      elsif lexical == '@prefix'
        error(:prefixID, "directive not terminated") unless terminated
      else
        error(:prefixID, "directive should not be terminated") if terminated
      end
      prefix(prefix, iri)
    end
    
    # [5] base set base_uri
    production(:base) do |input, current, callback|
      iri = current[:resource]
      lexical = current[:string_value]
      terminated = current[:terminated]
      debug("base") {"Defined base as #{iri}"}
      if lexical.start_with?('@') && lexical != '@base'
        error(:base, "should be downcased")
      elsif lexical == '@base'
        error(:base, "directive not terminated") unless terminated
      else
        error(:base, "directive should not be terminated") if terminated
      end
      options[:base_uri] = iri
    end
    
    # [6] triples
    start_production(:triples) do |input, current, callback|
      # Note production as triples for blankNodePropertyList
      # to set :subject instead of :resource
      current[:triples] = true
    end
    production(:triples) do |input, current, callback|
      # Note production as triples for blankNodePropertyList
      # to set :subject instead of :resource
      current[:triples] = true
    end

    # [9] verb ::= predicate | "a"
    production(:verb) do |input, current, callback|
      input[:predicate] = current[:resource]
    end

    # [10] subject ::= IRIref | BlankNode | collection
    start_production(:subject) do |input, current, callback|
      current[:triples] = nil
    end

    production(:subject) do |input, current, callback|
      input[:subject] = current[:resource]
    end

    # [12] object ::= iri | BlankNode | collection | blankNodePropertyList | literal
    production(:object) do |input, current, callback|
      if input[:object_list]
        # Part of an rdf:List collection
        input[:object_list] << current[:resource]
      else
        debug("object") {"current: #{current.inspect}"}
        callback.call(:statement, "object", input[:subject], input[:predicate], current[:resource])
      end
    end

    # [14] blankNodePropertyList ::= "[" predicateObjectList "]"
    start_production(:blankNodePropertyList) do |input, current, callback|
      current[:subject] = self.bnode
    end
    
    production(:blankNodePropertyList) do |input, current, callback|
      if input[:triples]
        input[:subject] = current[:subject]
      else
        input[:resource] = current[:subject]
      end
    end
    
    # [15] collection ::= "(" object* ")"
    start_production(:collection) do |input, current, callback|
      # Tells the object production to collect and not generate statements
      current[:object_list] = []
    end
    
    production(:collection) do |input, current, callback|
      # Create an RDF list
      objects = current[:object_list]
      list = RDF::List[*objects]
      list.each_statement do |statement|
        next if statement.predicate == RDF.type && statement.object == RDF.List
        callback.call(:statement, "collection", statement.subject, statement.predicate, statement.object)
      end

      # Return bnode as resource
      input[:resource] = list.subject
    end
    
    # [16] RDFLiteral ::= String ( LanguageTag | ( "^^" IRIref ) )? 
    production(:RDFLiteral) do |input, current, callback|
      opts = {}
      opts[:datatype] = current[:resource] if current[:resource]
      opts[:language] = current[:lang] if current[:lang]
      input[:resource] = literal(current[:string_value], opts)
    end

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
    # @option options [Boolean] :resolve_uris (false)
    #   Resolve prefix and relative IRIs, otherwise, when serializing the parsed SSE
    #   as S-Expressions, use the original prefixed and relative URIs along with `base` and `prefix`
    #   definitions.
    # @option options [Boolean]  :validate     (false)
    #   whether to validate the parsed statements and values. If not validating,
    #   the parser will attempt to recover from errors.
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
        @callback = block

        parse(@input, START.to_sym, @options.merge(branch:  BRANCH,
                                                   first:  FIRST,
                                                   follow:  FOLLOW,
                                                   reset_on_start:  true)
        ) do |context, *data|
          case context
          when :statement
            loc = data.shift
            s = RDF::Statement.from(data, lineno:  lineno)
            add_statement(loc, s) unless !s.valid? && validate?
          when :trace
            level, lineno, depth, *args = data
            message = "#{args.join(': ')}"
            d_str = depth > 100 ? ' ' * 100 + '+' : ' ' * depth
            str = "[#{lineno}](#{level})#{d_str}#{message}"
            case @options[:debug]
            when Array
              @options[:debug] << str
            when TrueClass
              $stderr.puts str
            when Integer
              $stderr.puts(str) if level <= @options[:debug]
            end
          end
        end
      end
      enum_for(:each_statement)
    rescue EBNF::LL1::Parser::Error, EBNF::LL1::Lexer::Error =>  e
      if validate?
        raise RDF::ReaderError.new(e.message, lineno: e.lineno, token: e.token)
      else
        $stderr.puts e.message
      end
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
    # @param [Nokogiri::XML::Node, any] node XML Node or string for showing context
    # @param [RDF::Statement] statement the subject of the statement
    # @return [RDF::Statement] Added statement
    # @raise [RDF::ReaderError] Checks parameter types and raises if they are incorrect if parsing mode is _validate_.
    def add_statement(node, statement)
      error(node, "Statement is invalid: #{statement.inspect.inspect}") if validate? && statement.invalid?
      progress(node) {"generate statement: #{statement.to_ntriples}"}
      @callback.call(statement) if statement.subject &&
                                   statement.predicate &&
                                   statement.object &&
                                   (validate? ? statement.valid? : true)
    end

    # Process a URI against base
    def process_iri(iri)
      value = base_uri.join(iri)
      value.validate! if validate?
      value.canonicalize! if canonicalize?
      value = RDF::URI.intern(value) if intern?
      value
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
        error("pname", "undefined prefix #{prefix.inspect}")
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
  end # class Reader
end # module RDF::Turtle
