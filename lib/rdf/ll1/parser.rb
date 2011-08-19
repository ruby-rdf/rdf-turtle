require 'rdf'
require 'rdf/ll1/lexer'

module RDF::LL1
  ##
  # A Generic LL1 parser using a lexer and branch tables defined using the SWAP tool chain (modified).
  module Parser
    ##
    # @attr [Integer] lineno
    attr_reader :lineno

    def self.included(base)
      base.extend(ClassMethods)
    end

    module ClassMethods
      def production_handlers; @production_handlers || {}; end
      def terminal_handlers; @terminal_handlers || {}; end
      def patterns; @patterns || []; end

      ##
      # Defines a production called durring different phases of parsing
      # with data from previous production along with data defined for the
      # current production
      #
      # @param [Symbol] term
      #   Term which is a key in the branch table
      # @yield [phase, input, current]
      # @yieldparam [Symbol] phase
      #   Phase of parsing, one of :start, or :finish
      # @yieldparam [Hash] input
      #   A Hash containing input from the parent production
      # @yieldparam [Hash] current
      #   A Hash defined for the current production, during :start
      #   may be initialized with data to pass to further productions,
      #   during :finish, it contains data placed by earlier productions
      # @yieldparam [Prod] block
      #   Block passed to initialization for yielding to calling reader.
      #   Should conform to the yield specs for #initialize
      # Yield to generate a triple
      def production(term, &block)
        @production_handlers ||= {}
        @production_handlers[term] = block
      end

      ##
      # Defines the pattern for a terminal node and a block to be invoked
      # when ther terminal is encountered. If the block is missing, the
      # value of the terminal will be placed on the input hash to be returned
      # to a previous production.
      #
      # @param [Symbol, String] term
      #   Defines a terminal production, which appears as within a sequence in the branch table
      # @param [Regexp] regexp
      #   Pattern used to scan for this terminal
      # @yield [term, token, input]
      # @yieldparam [Symbol] term
      #   A symbol indicating the production which referenced this terminal
      # @yieldparam [String] token
      #   The scanned token
      # @yieldparam [Hash] input
      #   A Hash containing input from the parent production
      # @yieldparam [Prod] block
      #   Block passed to initialization for yielding to calling reader.
      #   Should conform to the yield specs for #initialize
      def terminal(term, regexp, &block)
        @patterns ||= []
        @patterns << [term, regexp]  # Passed in order to define evaulation sequence
        @terminal_handlers ||= {}
        @terminal_handlers[term] = block
      end
    end

    ##
    # Initializes a new parser instance.
    #
    # @example
    #   require 'rdf/ll1/parser'
    #   
    #   class Reader << RDF::Reader
    #     include RDF::LL1::Parser
    #     
    #     branch      RDF::Turtle::Reader::BRANCH
    #     
    #     ##
    #     # Defines a production called durring different phases of parsing
    #     # with data from previous production along with data defined for the
    #     # current production
    #     #
    #     # Yield to generate a triple
    #     production :object do |phase, input, current|
    #       object = current[:resource]
    #       yield :statement, RDF::Statement.new(input[:subject], input[:predicate], object)
    #     end
    #     
    #     ##
    #     # Defines the pattern for a terminal node
    #     terminal :BLANK_NODE_LABEL, %r(_:(#{PN_LOCAL})) do |production, terminal, token, input|
    #       input[:BLANK_NODE_LABEL] = RDF::Node.new(token)
    #     end
    #     
    #     ##
    #     # Iterates the given block for each RDF statement in the input.
    #     #
    #     # @yield  [statement]
    #     # @yieldparam [RDF::Statement] statement
    #     # @return [void]
    #     def each_statement(&block)
    #       @callback = block
    #   
    #       parse(START.to_sym) do |context, *data|
    #         case context
    #         when :statement
    #           yield *data
    #         end
    #       end
    #     end
    #     
    #   end
    #
    # @param  [String, #to_s]          input
    # @param [Symbol, #to_s] prod The starting production for the parser.
    #   It may be a URI from the grammar, or a symbol representing the local_name portion of the grammar URI.
    # @param  [Hash{Symbol => Object}] options
    # @option options [Boolean] :progress
    #   Show progress of parser productions
    # @option options [Boolean] :debug
    #   Detailed debug output
    # @yield [context, *data]
    #   Yields for to return data to reader
    # @yieldparam [:statement, :trace] context
    #   Context for block
    # @yieldparam [Symbol] *data
    #   Data specific to the call
    # @return [RDF::LL1::Parser]
    def parse(input = nil, prod = nil, options = {}, &block)
      @options = options.dup
      @branch  = options[:branch]
      @lexer   = input.is_a?(Lexer) ? input : Lexer.new(input, self.class.patterns, @options)
      @productions = []
      @callback = block
      terminals = self.class.patterns.map(&:first)  # Get defined terminals to help with branching

      raise Error, "Branch table not defined" unless @branch && @branch.length > 0
      raise Error, "Starting production not defined" unless prod

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
                "depth #{depth}")
          
          # Got an opened production
          cur_prod = todo_stack.last[:prod]
          # Got an opened production
          onStart(cur_prod)
          break if token.nil?
          
          prod_branch = @branch[cur_prod]
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
        
        debug("parse(terms)", "todo #{todo_stack.last.inspect}, depth #{depth}")
        while !todo_stack.last[:terms].to_a.empty?
          # Get the next term in this sequence
          term = todo_stack.last[:terms].shift
          if token = accept(term)
            debug("parse(token)", "#{token.inspect}, term #{term.inspect}")
            @lineno = token.lineno if token
            onToken(term, token.value)
          elsif terminals.include?(term)
            error("parse", "#{term.inspect} expected",
              :production => todo_stack.last[:prod], :token => @lexer.first)
          else
            # If it's not a string (a symbol), it is a non-terminal and we push the new state
            todo_stack << {:prod => term, :terms => nil}
            debug("parse(push)", "term #{term.inspect}, depth #{depth}")
            pushed = true
            break
          end
        end
        
        # After completing the last production in a sequence, pop down until we find a production
        while !pushed && !todo_stack.empty? && todo_stack.last[:terms].to_a.empty?
          debug("parse(pop)", "todo #{todo_stack.last.inspect}, depth #{depth}")
          todo_stack.pop
          onFinish
        end
      end

      error("parse(eof)", "Finished processing before end of file", :token => @lexer.first) if @lexer.first

      # Continue popping contexts off of the stack
      while !todo_stack.empty?
        debug("parse(eof)", "stack #{todo_stack.last.inspect}, depth #{depth}")
        todo_stack.pop
        onFinish
      end

    rescue RDF::LL1::Lexer::Error => e
      @lineno = e.lineno
      error("parse", "With input '#{e.input[0..100]}': #{e.message}",
            :production => @productions.last)
    end

    def depth; (@productions || []).length; end

  private
    # Start for production
    def onStart(prod)
      handler = self.class.production_handlers[prod]
      @productions << prod
      if handler
        # Create a new production data element, potentially allowing handler
        # to customize before pushing on the @prod_data stack
        progress("#{prod}(:start):#{@prod_data.length}", @prod_data.last)
        data = {}
        handler.call(:start, @prod_data.last, data) do |context, *data|
          @callback.call(context, data) if @callback
        end
        @prod_data << data
      else
        progress("#{prod}(:start)", '')
      end
      #puts @prod_data.inspect
    end

    # Finish of production
    def onFinish
      prod = @productions.last
      handler = self.class.production_handlers[prod]
      if handler
        # Pop production data element from stack, potentially allowing handler to use it
        data = @prod_data.pop
        handler.call(:finish, @prod_data.last, data) do |context, *data|
          @callback.call(context, data) if @callback
        end
        progress("#{prod}(:finish):#{@prod_data.length}", prod_data, :depth => depth)
      else
        progress("#{prod}(:finish)", '', :depth => depth)
      end
      @productions.pop
    end

    # A token
    def onToken(prod, token)
      unless @productions.empty?
        parentProd = @productions.last
        handler = self.class.terminal_handlers[prod]
        if handler
          handler.call(parentProd, token, @prod_data.last) do |context, *data|
            @callback.call(context, data) if @callback
          end
          progress("#{prod}<#{parentProd}(:token)", "#{token}: #{prod_data}", :depth => (depth + 1))
        else
          progress("#{prod}<#{parentProd}(:token)", token, :depth => (depth + 1))
        end
      else
        error("#{parentProd}(:token)", "Token has no parent production", :production => prod)
      end
    end

    # @param [String] str Error string
    # @param [Hash] options
    # @option options [URI, #to_s] :production
    # @option options [Token] :token
    def error(node, message, options = {})
      message += ", found #{options[:token].representation.inspect}" if options[:token]
      message += " at line #{@lineno}" if @lineno
      message += ", production = #{options[:production].inspect}" if options[:production] #&& options[:debug]
      raise Error, message
    end

    ##
    # Progress output when parsing
    # @param [String] str
    def progress(node, message, options = {})
      return unless @options[:progress]
      depth = options[:depth] || self.depth
      str = "[#{@lineno}]#{' ' * depth}#{node}: #{message}"
      $stderr.puts("[#{@lineno}]#{' ' * depth}#{node}: #{message}")
    end

    ##
    # Progress output when debugging
    # @param [String] node Relevant location associated with message
    # @param [String] message
    # @param [Hash] options
    # @option options [Integer] :depth
    #   Recursion depth for indenting output
    def debug(node, message, options = {})
      depth = options[:depth] || self.depth
      str = "[#{@lineno}]#{' ' * depth}#{node}: #{message}"
      case @options[:debug]
      when Array
        @options[:debug] << str
      when TrueClass
        $stderr.puts str
      when :yield
        @callback.call(:debug, node, message, options)
      end
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
  public

    ##
    # Raised for errors during parsing.
    #
    # @example Raising a parser error
    #   raise Error.new(
    #     "invalid token '%' on line 10",
    #     :token => '%', :lineno => 9, :production => :turtleDoc)
    #
    # @see http://ruby-doc.org/core/classes/StandardError.html
    class Error < StandardError
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
      # Initializes a new lexer error instance.
      #
      # @param  [String, #to_s]          message
      # @param  [Hash{Symbol => Object}] options
      # @option options [Symbol]         :production  (nil)
      # @option options [String]         :token  (nil)
      # @option options [Integer]        :lineno (nil)
      def initialize(message, options = {})
        @production = options[:production]
        @token      = options[:token]
        @lineno     = options[:lineno]
        super(message.to_s)
      end
    end # class Error
  end # class Reader
end # module RDF::Turtle
