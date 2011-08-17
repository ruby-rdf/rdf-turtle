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
    def initialize(input = nil, options = {}, &block)
      super do
        @options = {:anon_base => "b0", :validate => false}.merge(options)
        @lexer   = input.is_a?(Lexer) ? input : Lexer.new(input, @options)
        @productions = []

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
          token = @lexer.first
          @lineno = token.lineno if token
          debug("parse(production)",
                "#{token ? token.representation.inspect : 'nil'}, " + 
                "prod #{todo_stack.last[:prod].inspect}, " + 
                "depth #{todo_stack.length}")
          
          # Got an opened production
          onStart(abbr(todo_stack.last[:prod]))
          break if token.nil?
          
          cur_prod = todo_stack.last[:prod]
          prod_branch = BRANCH[cur_prod]
          error("parse", "No branches found for #{cur_prod.inspect}",
            :production => cur_prod, :token => token) unless prod_branch
          sequence = prod_branch[token.representation]
          debug("parse(production)",
                "#{token.representation.inspect} " +
                "prod #{cur_prod.inspect}, " + 
                "prod_branch #{prod_branch.keys.inspect}, " +
                "sequence #{sequence.inspect}")
          if sequence.nil?
            if prod_branch.has_key?(:"ebnf:empty")
              debug("parse(production)", "empty sequence for ebnf:empty")
              sequence ||= []
            else
              expected = prod_branch.keys.map {|v| v.inspect}.join(", ")
              error("parse", "expected one of #{expected}",
                :production => cur_prod, :token => token)
            end
          end
          todo_stack.last[:terms] += sequence
        end
        
        debug("parse(terms)", "todo #{todo_stack.last.inspect}, depth #{todo_stack.length}")
        while !todo_stack.last[:terms].to_a.empty?
          # Get the next term in this sequence
          term = todo_stack.last[:terms].shift
          if token = accept(term)
            debug("parse(token)", "#{token.inspect}, term #{term.inspect}")
            @lineno = token.lineno if token
            onToken(abbr(term), token.value)
          elsif TERMINALS.include?(term)
            error("parse", "#{term.inspect} expected",
              :production => todo_stack.last[:prod], :token => @lexer.first)
          else
            # If it's not a string (a symbol), it is a non-terminal and we push the new state
            todo_stack << {:prod => term, :terms => nil}
            debug("parse(push)", "term #{term.inspect}, depth #{todo_stack.length}")
            pushed = true
            break
          end
        end
        
        # After completing the last production in a sequence, pop down until we find a production
        while !pushed && !todo_stack.empty? && todo_stack.last[:terms].to_a.empty?
          debug("parse(pop)", "todo #{todo_stack.last.inspect}, depth #{todo_stack.length}")
          todo_stack.pop
          onFinish
        end
      end

      error("parse(eof)", "Finished processing before end of file", :token => @lexer.first) if @lexer.first

      # Continue popping contexts off of the stack
      while !todo_stack.empty?
        debug("parse(eof)", "stack #{todo_stack.last.inspect}, depth #{todo_stack.length}")
        todo_stack.pop
        onFinish
      end

    rescue RDF::Turtle::Lexer::Error => e
      @lineno = e.lineno
      error("parse", "With input #{e.input.inspect}: #{e.message}")
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
      message += ", found #{options[:token].representation.inspect}" if options[:token]
      message += " at line #{@lineno}" if @lineno
      message += ", production = #{options[:production].inspect}" if options[:production] #&& options[:debug]
      raise RDF::ReaderError, message
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
      str = "[#{@lineno}]#{' ' * depth}#{node}: #{message}"
      @options[:debug] << str if @options[:debug].is_a?(Array)
      $stderr.puts("[#{@lineno}]#{' ' * depth}#{node}: #{message}") if RDF::Turtle.debug?
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
      if (token = @lexer.first) && token === type_or_value
        debug("accept", "#{token.inspect} === #{type_or_value}.inspect")
        @lexer.shift
      end
    end
  end # class Reader
end # module RDF::Turtle
