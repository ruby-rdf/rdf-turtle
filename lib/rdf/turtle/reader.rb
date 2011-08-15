require 'rdf/turtle/meta'

module RDF::Turtle
  ##
  # A parser for the Turtle 2
  class Reader < RDF::Reader
    format Format
    include RDF::Turtle::Meta

    ##
    # Missing in 0.3.2
    def base_uri
      @options[:base_uri]
    end

    ##
    # The current input tokens being processed.
    #
    # @return [Array<Token>]
    attr_reader   :tokens

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
    # @return [SPARQL::Grammar::Parser]
    def initialize(input = nil, options = {})
      super do
        @options = {:anon_base => "b0", :validate => false}.merge(options)
        lexer   = input.is_a?(Lexer) ? input : Lexer.new(input, @options)
        @input  = lexer.input
        @tokens = lexer.to_a
        @productions = []

        # Spec Confusion, not mentioned in Turtle spec
        #if options[:base_uri]
        #  add_debug("@uri", "#{base_uri.inspect}")
        #  namespace(nil, uri("#{base_uri}#"))
        #end
        add_debug("validate", "#{validate?.inspect}")
        add_debug("canonicalize", "#{canonicalize?.inspect}")
        add_debug("intern", "#{intern?.inspect}")

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

      parse(START.to_sym)
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

    # Parse query
    #
    # The result is a SPARQL Algebra S-List. Productions return an array such as the following:
    #
    #   (prefix ((: <http://example/>))
    #     (union
    #       (bgp (triple ?s ?p ?o))
    #       (graph ?g
    #         (bgp (triple ?s ?p ?o)))))
    #
    # @param [Symbol, #to_s] prod The starting production for the parser.
    #   It may be a URI from the grammar, or a symbol representing the local_name portion of the grammar URI.
    # @return [Array]
    # @see http://www.w3.org/2001/sw/DataAccess/rq23/rq24-algebra.html
    # @see http://axel.deri.ie/sparqltutorial/ESWC2007_SPARQL_Tutorial_unit2b.pdf
    def parse(prod = START)
      @prod_data = [{}]
      prod = RDF::URI(prod).fragment.to_sym unless prod.is_a?(Symbol)
      todo_stack = [{:prod => prod, :terms => nil}]

      while !todo_stack.empty?
        pushed = false
        if todo_stack.last[:terms].nil?
          todo_stack.last[:terms] = []
          token = tokens.first
          @lineno = token.lineno if token
          debug("parse(token)", "#{token.inspect}, prod #{todo_stack.last[:prod]}, depth #{todo_stack.length}")
          
          # Got an opened production
          onStart(abbr(todo_stack.last[:prod]))
          break if token.nil?
          
          cur_prod = todo_stack.last[:prod]
          prod_branch = BRANCH[cur_prod.to_sym]
          error("parse", "No branches found for #{cur_prod.to_sym.inspect}",
            :production => cur_prod, :token => token) if prod_branch.nil?
          sequence = prod_branch[token.representation]
          debug("parse(production)", "cur_prod #{cur_prod}, token #{token.representation.inspect} prod_branch #{prod_branch.keys.inspect}, sequence #{sequence.inspect}")
          if sequence.nil? && !prod_branch.has_key?(:"ebnf:empty")
            expected = prod_branch.values.uniq.map {|u| u.map {|v| abbr(v).inspect}.join(",")}
            error("parse", "Found '#{token.inspect}' when parsing #{abbr(cur_prod)}. expected #{expected.join(' | ')}",
              :production => cur_prod, :token => token)
          else
            sequence ||= []
          end
          todo_stack.last[:terms] += sequence
        end
        
        debug("parse(terms)", "stack #{todo_stack.last.inspect}, depth #{todo_stack.length}")
        while !todo_stack.last[:terms].to_a.empty?
          term = todo_stack.last[:terms].shift
          debug("parse tokens(#{term})", tokens.inspect)
          if tokens.map(&:representation).include?(term)  # FIXME: Shouldn't this just look at the current token?
            token = accept(term)
            @lineno = token.lineno if token
            debug("parse", "term(#{token.inspect}): #{term}")
            if token
              onToken(abbr(term), token.value)
            else
              error("parse", "Found '#{word}...'; #{term} expected",
                :production => todo_stack.last[:prod], :token => tokens.first)
            end
          else
            todo_stack << {:prod => term, :terms => nil}
            debug("parse(push)", "stack #{term}, depth #{todo_stack.length}")
            pushed = true
            break
          end
        end
        
        while !pushed && !todo_stack.empty? && todo_stack.last[:terms].to_a.empty?
          debug("parse(pop)", "stack #{todo_stack.last.inspect}, depth #{todo_stack.length}")
          todo_stack.pop
          onFinish
        end
      end
      while !todo_stack.empty?
        debug("parse(pop)", "stack #{todo_stack.last.inspect}, depth #{todo_stack.length}")
        todo_stack.pop
        onFinish
      end
    end

    # Handlers used to define actions for each productions.
    # If a context is defined, create a producation data element and add to the @prod_data stack
    # If entries are defined, pass production data to :start and/or :finish handlers
    def contexts(production)
      case production
      when :BaseDecl
        # [3]     BaseDecl      ::=       'BASE' IRI_REF
        {
          :finish => lambda { |data|
            self.base_uri = uri(data[:iri].last)
            add_prod_datum(:BaseDecl, data[:iri].last) unless options[:resolve_uris]
          }
        }
      end
    end

    # Start for production
    def onStart(prod)
      context = contexts(prod.to_sym)
      @productions << prod
      if context
        # Create a new production data element, potentially allowing handler
        # to customize before pushing on the @prod_data stack
        progress("#{prod}(:start):#{@prod_data.length}", prod_data)
        data = {}
        context[:start].call(data) if context.has_key?(:start)
        @prod_data << data
      else
        progress("#{prod}(:start)", '')
      end
      #puts @prod_data.inspect
    end

    # Finish of production
    def onFinish
      prod = @productions.pop()
      context = contexts(prod.to_sym)
      if context
        # Pop production data element from stack, potentially allowing handler to use it
        data = @prod_data.pop
        context[:finish].call(data) if context.has_key?(:finish)
        progress("#{prod}(:finish):#{@prod_data.length}", prod_data, :depth => (@productions.length + 1))
      else
        progress("#{prod}(:finish)", '', :depth => (@productions.length + 1))
      end
    end

    # Handlers for individual tokens based on production
    def token_productions(parent_production, production)
      case parent_production
      when :Boolean
        lit = RDF::Literal::Boolean.new(tok.delete("@"), :validate => validate?, :canonicalize => canonicalize?)
        add_prod_data(:literal, lit)
      end
    end
    
    # A token
    def onToken(prod, token)
      unless @productions.empty?
        parentProd = @productions.last
        token_production = token_productions(parentProd.to_sym, prod.to_sym)
        if token_production
          token_production.call(token)
          progress("#{prod}<#{parentProd}(:token)", "#{token}: #{prod_data}", :depth => (@productions.length + 1))
        else
          progress("#{prod}<#{parentProd}(:token)", token, :depth => (@productions.length + 1))
        end
      else
        error("#{parentProd}(:token)", "Token has no parent production", :production => prod)
      end
    end

    # Current ProdData element
    def prod_data; @prod_data.last; end
    
    # @param [String] str Error string
    # @param [Hash] options
    # @option options [URI, #to_s] :production
    # @option options [Token] :token
    def error(node, message, options = {})
      depth = options[:depth] || @productions.length
      node ||= options[:production]
      raise Error.new("Error on production #{options[:production].inspect}#{' with input ' + options[:token].inspect if options[:token]} at line #{@lineno}: #{message}", options)
    end

    ##
    # Progress output when parsing
    # @param [String] str
    def progress(node, message, options = {})
      depth = options[:depth] || @productions.length
      $stderr.puts("[#{@lineno}]#{' ' * depth}#{node}: #{message}") if @options[:progress]
    end

    ##
    # Progress output when debugging
    # @param [String] str
    def debug(node, message, options = {})
      depth = options[:depth] || @productions.length
      $stderr.puts("[#{@lineno}]#{' ' * depth}#{node}: #{message}") if @options[:debug]
    end

    ##
    # @return [void]
    def fail
      false
    end
    alias_method :fail!, :fail

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
      add_debug("namespace", "'#{prefix}' <#{uri}>")
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

    # Add debug event to debug array, if specified
    #
    # @param [XML Node, any] node:: XML Node or string for showing context
    # @param [String] message::
    def add_debug(node, message)
      puts "[#{@lineno},#{@pos}]#{' ' * @productions.length}#{node}: #{message}" if ::RDF::Turtle::debug?
      @options[:debug] << "[#{@lineno},#{@pos}]#{' ' * @productions.length}#{node}: #{message}" if @options[:debug].is_a?(Array)
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
      context_opts = {:context => @formulae.last.context} if @formulae.last
      
      # Replace graph with it's context
      subject = subject.context if subject.graph?
      object = object.context if object.graph?
      statement = RDF::Statement.new(subject, predicate, object, context_opts || {})
      add_debug(node, statement.to_s)
      @callback.call(statement)
    end

    def abbr(prodURI)
      prodURI.to_s.split('#').last
    end

    ##
    # @param  [Symbol, String] type_or_value
    # @return [Token]
    def accept(type_or_value)
      if (token = tokens.first) && token === type_or_value
        tokens.shift
      end
    end

  public
    ##
    # Raised for errors during parsing.
    #
    # @example Raising a parser error
    #   raise SPARQL::Grammar::Parser::Error.new(
    #     "FIXME on line 10",
    #     :input => query, :production => '%', :lineno => 9)
    #
    # @see http://ruby-doc.org/core/classes/StandardError.html
    class Error < StandardError
      ##
      # The input string associated with the error.
      #
      # @return [String]
      attr_reader :input

      ##
      # The grammar production where the error was found.
      #
      # @return [String]
      attr_reader :production

      ##
      # The line number where the error occurred.
      #
      # @return [Integer]
      attr_reader :lineno

      ##
      # Position within line of error.
      #
      # @return [Integer]
      attr_reader :position

      ##
      # Initializes a new lexer error instance.
      #
      # @param  [String, #to_s]          message
      # @param  [Hash{Symbol => Object}] options
      # @option options [String]         :input  (nil)
      # @option options [String]         :production  (nil)
      # @option options [Integer]        :lineno (nil)
      # @option options [Integer]        :position (nil)
      def initialize(message, options = {})
        @input  = options[:input]
        @production  = options[:production]
        @lineno = options[:lineno]
        @position = options[:position]
        super(message.to_s)
      end
    end # class Error
  end # class Reader
end # module RDF::Turtle
