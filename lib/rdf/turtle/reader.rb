require 'rdf/turtle/meta'

module RDF::Turtle
  ##
  # A parser for the Turtle 2
  class Reader < RDF::Reader
    include RDF::Turtle::Meta

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
      @options = {:anon_base => "b0", :validate => false}.merge(options)
      self.input = input if input
      @productions = []
    end

    ##
    # The current input tokens being processed.
    #
    # @return [Array<Token>]
    attr_reader   :tokens

    ##
    # @param  [IO, StringIO, Lexer, Array, String, #to_s] input
    #   Query may be an array of lexed tokens, a lexer, or a
    #   string or open file.
    # @return [void]
    def input=(input)
      case input
        when Array
          @input  = nil # FIXME
          @tokens = input
        else
          lexer   = input.is_a?(Lexer) ? input : Lexer.new(input, @options)
          @input  = lexer.input
          @tokens = lexer.to_a
      end
    end

  private

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
      when :PrefixDecl
        # [4] PrefixDecl := 'PREFIX' PNAME_NS IRI_REF";
        {
          :finish => lambda { |data|
            if data[:iri]
              self.prefix(data[:prefix], data[:iri].last)
              add_prod_data(:PrefixDecl, data[:iri].unshift("#{data[:prefix]}:".to_sym))
            end
          }
        }
      when :GroupGraphPattern
        # [20] GroupGraphPattern ::= '{' TriplesBlock? ( ( GraphPatternNotTriples | Filter ) '.'? TriplesBlock? )* '}'
        {
          :finish => lambda { |data|
            query_list = data[:query_list]
            debug "GroupGraphPattern", "ql #{query_list.to_a.inspect}"
            debug "GroupGraphPattern", "q #{data[:query] ? data[:query].first.inspect : 'nil'}"
            
            if query_list
              lhs = data[:query].to_a.first
              while !query_list.empty?
                rhs = query_list.shift
                # Make the right-hand-side a Join with only a single operand, if it's not already and Operator
                rhs = Algebra::Expression.for(:join, :placeholder, rhs) unless rhs.is_a?(Algebra::Operator)
                debug "GroupGraphPattern(itr)", "<= q: #{rhs.inspect}"
                debug "GroupGraphPattern(itr)", "<= lhs: #{lhs ? lhs.inspect : 'nil'}"
                lhs ||= RDF::Query.new if rhs.is_a?(Algebra::Operator::LeftJoin)
                if lhs
                  if rhs.operand(0) == :placeholder
                    rhs.operands[0] = lhs
                  else
                    rhs = Algebra::Operator::Join.new(lhs, rhs)
                  end
                end
                lhs = rhs
                lhs = lhs.operand(1) if lhs.operand(0) == :placeholder
                debug "GroupGraphPattern(itr)", "=> lhs: #{lhs.inspect}"
              end
              # Trivial simplification for :join or :union of one query
              case lhs
              when Algebra::Operator::Join, Algebra::Operator::Union
                if lhs.operand(0) == :placeholder
                  lhs = lhs.operand(1)
                  debug "GroupGraphPattern(simplify)", "=> lhs: #{lhs.inspect}"
                end
              end
              res = lhs
            elsif data[:query]
              res = data[:query].first
            end
            
            debug "GroupGraphPattern(pre-filter)", "res: #{res.inspect}"

            if data[:filter]
              expr, query = flatten_filter(data[:filter])
              query = res || RDF::Query.new
              # query should be nil
              res = Algebra::Operator::Filter.new(expr, query)
            end
            add_prod_datum(:query, res)
          }
        }
      when :TriplesSameSubject
        # [32]    TriplesSameSubject ::= VarOrTerm PropertyListNotEmpty | TriplesNode PropertyList
        {
          :finish => lambda { |data| add_prod_datum(:pattern, data[:pattern]) }
        }
      when :PropertyListNotEmpty
        # [33]    PropertyListNotEmpty ::= Verb ObjectList ( ';' ( Verb ObjectList )? )*
        {
          :start => lambda {|data|
            subject = prod_data[:VarOrTerm] || prod_data[:TriplesNode] || prod_data[:GraphNode]
            error(nil, "Expected VarOrTerm or TriplesNode or GraphNode", :production => :PropertyListNotEmpty) if validate? && !subject
            data[:Subject] = subject
          },
          :finish => lambda {|data| add_prod_datum(:pattern, data[:pattern])}
        }
      when :ObjectList
        # [35]    ObjectList ::= Object ( ',' Object )*
        {
          :start => lambda { |data|
            # Called after Verb. The prod_data stack should have Subject and Verb elements
            data[:Subject] = prod_data[:Subject]
            error(nil, "Expected Subject", :production => :ObjectList) if validate?
            error(nil, "Expected Verb", :production => :ObjectList) if validate?
            data[:Subject] = prod_data[:Subject]
            data[:Verb] = prod_data[:Verb].to_a.last
          },
          :finish => lambda { |data| add_prod_datum(:pattern, data[:pattern]) }
        }
      when :Object
        # [36]    Object ::= GraphNode
        {
          :finish => lambda { |data|
            object = data[:VarOrTerm] || data[:TriplesNode] || data[:GraphNode]
            if object
              add_pattern(:Object, :subject => prod_data[:Subject], :predicate => prod_data[:Verb], :object => object)
              add_prod_datum(:pattern, data[:pattern])
            end
          }
        }
      when :Verb
        # [37]    Verb ::=       VarOrIRIref | 'a'
        {
          :finish => lambda { |data| data.values.each {|v| add_prod_datum(:Verb, v)} }
        }
      when :TriplesNode
        # [38]    TriplesNode ::= Collection | BlankNodePropertyList
        #
        # Allocate Blank Node for () or []
        {
          :start => lambda { |data| data[:TriplesNode] = gen_node() },
          :finish => lambda { |data| 
            add_prod_datum(:pattern, data[:pattern])
            add_prod_datum(:TriplesNode, data[:TriplesNode])
          }
        }
      when :Collection
        # [40]    Collection ::= '(' GraphNode+ ')'
        {
          :start => lambda { |data| data[:Collection] = prod_data[:TriplesNode]},
          :finish => lambda { |data| expand_collection(data) }
        }
      when :GraphTerm
        # [45]    GraphTerm ::= IRIref | RDFLiteral | NumericLiteral | BooleanLiteral | BlankNode | NIL
        {
          :finish => lambda { |data|
            add_prod_datum(:GraphTerm, data[:IRIref] || data[:literal] || data[:BlankNode] || data[:NIL])
          }
        }
      when :Expression
        # [46] Expression ::=       ConditionalOrExpression
        {
          :finish => lambda { |data| add_prod_datum(:Expression, data[:Expression]) }
        }
      when :ConditionalOrExpression
        # [47]    ConditionalOrExpression   ::=       ConditionalAndExpression ( '||' ConditionalAndExpression )*
        {
          :finish => lambda { |data| add_operator_expressions(:_OR, data) }
        }
      when :_OR_ConditionalAndExpression
        # This part handles the operator and the rhs of a ConditionalAndExpression
        {
          :finish => lambda { |data| accumulate_operator_expressions(:ConditionalOrExpression, :_OR, data) }
        }
      when :ConditionalAndExpression
        # [48]    ConditionalAndExpression  ::=       ValueLogical ( '&&' ValueLogical )*
        {
          :finish => lambda { |data| add_operator_expressions(:_AND, data) }
        }
      when :_AND_ValueLogical_Star
        # This part handles the operator and the rhs of a ConditionalAndExpression
        {
          :finish => lambda { |data| accumulate_operator_expressions(:ConditionalAndExpression, :_AND, data) }
        }
      when :RelationalExpression
        # [50] RelationalExpression ::= NumericExpression (
        #                                   '=' NumericExpression
        #                                 | '!=' NumericExpression
        #                                 | '<' NumericExpression
        #                                 | '>' NumericExpression
        #                                 | '<=' NumericExpression
        #                                 | '>=' NumericExpression )?
        # 
        {
          :finish => lambda { |data|
            if data[:_Compare_Numeric]
              add_prod_datum(:Expression, Algebra::Expression.for(data[:_Compare_Numeric].insert(1, *data[:Expression])))
            else
              # NumericExpression with no comparitor
              add_prod_datum(:Expression, data[:Expression])
            end
          }
        }
      when :_Compare_NumericExpression_Opt  # ( '=' NumericExpression | '!=' NumericExpression | ... )?
        # This part handles the operator and the rhs of a RelationalExpression
        {
          :finish => lambda { |data|
            if data[:RelationalExpression]
              add_prod_datum(:_Compare_Numeric, data[:RelationalExpression] + data[:Expression])
            end
          }
        }
      when :AdditiveExpression
        # [52]    AdditiveExpression ::= MultiplicativeExpression ( '+' MultiplicativeExpression | '-' MultiplicativeExpression )*
        {
          :finish => lambda { |data| add_operator_expressions(:_Add_Sub, data) }
        }
      when :_Add_Sub_MultiplicativeExpression_Star  # ( '+' MultiplicativeExpression | '-' MultiplicativeExpression | ... )*
        # This part handles the operator and the rhs of a AdditiveExpression
        {
          :finish => lambda { |data| accumulate_operator_expressions(:AdditiveExpression, :_Add_Sub, data) }
        }
      when :MultiplicativeExpression
        # [53]    MultiplicativeExpression  ::=       UnaryExpression ( '*' UnaryExpression | '/' UnaryExpression )*
        {
          :finish => lambda { |data| add_operator_expressions(:_Mul_Div, data) }
        }
      when :_Mul_Div_UnaryExpression_Star # ( '*' UnaryExpression | '/' UnaryExpression )*
        # This part handles the operator and the rhs of a MultiplicativeExpression
        {
          # Mul or Div with prod_data[:Expression]
          :finish => lambda { |data| accumulate_operator_expressions(:MultiplicativeExpression, :_Mul_Div, data) }
        }
      when :UnaryExpression
        # [54] UnaryExpression ::=  '!' PrimaryExpression | '+' PrimaryExpression | '-' PrimaryExpression | PrimaryExpression
        {
          :finish => lambda { |data|
            case data[:UnaryExpression]
            when [:"!"]
              add_prod_datum(:Expression, Algebra::Expression[:not, data[:Expression].first])
            when [:"-"]
              e = data[:Expression].first
              if e.is_a?(RDF::Literal::Numeric)
                add_prod_datum(:Expression, -e) # Simple optimization to match ARQ generation
              else
                add_prod_datum(:Expression, Algebra::Expression[:minus, e])
              end
            else
              add_prod_datum(:Expression, data[:Expression])
            end
          }
        }
      when :PrimaryExpression
        # [55] PrimaryExpression ::= BrackettedExpression | BuiltInCall | IRIrefOrFunction | RDFLiteral | NumericLiteral | BooleanLiteral | Var
        {
          :finish => lambda { |data|
            if data[:Expression]
              add_prod_datum(:Expression, data[:Expression])
            elsif data[:BuiltInCall]
              add_prod_datum(:Expression, data[:BuiltInCall])
            elsif data[:IRIref]
              add_prod_datum(:Expression, data[:IRIref])
            elsif data[:Function]
              add_prod_datum(:Expression, data[:Function]) # Maintain array representation
            elsif data[:literal]
              add_prod_datum(:Expression, data[:literal])
            elsif data[:Var]
              add_prod_datum(:Expression, data[:Var])
            end
            
            add_prod_datum(:UnaryExpression, data[:UnaryExpression]) # Keep track of this for parent UnaryExpression production
          }
        }
      when :BuiltInCall
        # [57] BuiltInCall ::= 'STR' '(' Expression ')'
        #                    | 'LANG' '(' Expression ')'
        #                    | 'LANGMATCHES' '(' Expression ',' Expression ')'
        #                    | 'DATATYPE' '(' Expression ')'
        #                    | 'BOUND' '(' Var ')'
        #                    | 'sameTerm' '(' Expression ',' Expression ')'
        #                    | 'isIRI' '(' Expression ')'
        #                    | 'isURI' '(' Expression ')'
        #                    | 'isBLANK' '(' Expression ')'
        #                    | 'isLITERAL' '(' Expression ')'
        #                    | RegexExpression
        {
          :finish => lambda { |data|
            if data[:regex]
              add_prod_datum(:BuiltInCall, Algebra::Expression.for(data[:regex].unshift(:regex)))
            elsif data[:BOUND]
              add_prod_datum(:BuiltInCall, Algebra::Expression.for(data[:Var].unshift(:bound)))
            elsif data[:BuiltInCall]
              add_prod_datum(:BuiltInCall, Algebra::Expression.for(data[:BuiltInCall] + data[:Expression]))
            end
          }
        }
      when :RegexExpression
        # [58]    RegexExpression           ::=       'REGEX' '(' Expression ',' Expression ( ',' Expression )? ')'
        {
          :finish => lambda { |data| add_prod_datum(:regex, data[:Expression]) }
        }
      when :IRIrefOrFunction
        # [59]    IRIrefOrFunction          ::=       IRIref ArgList?
        {
          :finish => lambda { |data|
            if data.has_key?(:ArgList)
              # Function is (func arg1 arg2 ...)
              add_prod_data(:Function, data[:IRIref] + data[:ArgList])
            else
              add_prod_datum(:IRIref, data[:IRIref])
            end
          }
        }
      when :RDFLiteral
        # [60]    RDFLiteral ::= String ( LANGTAG | ( '^^' IRIref ) )?
        {
          :finish => lambda { |data|
            if data[:string]
              lit = data.dup
              str = lit.delete(:string).last 
              lit[:datatype] = lit.delete(:IRIref).last if lit[:IRIref]
              lit[:language] = lit.delete(:language).last.downcase if lit[:language]
              add_prod_datum(:literal, RDF::Literal.new(str, lit)) if str
            end
          }
        }
      when :NumericLiteralPositive
        # [63]    NumericLiteralPositive    ::=       INTEGER_POSITIVE | DECIMAL_POSITIVE | DOUBLE_POSITIVE
        {
          :finish => lambda { |data|
            num = data.values.flatten.last
            add_prod_datum(:literal, num.class.new("+#{num.value}"))
            add_prod_datum(:UnaryExpression, data[:UnaryExpression]) # Keep track of this for parent UnaryExpression production
          }
        }
      when :NumericLiteralNegative
        # [64]    NumericLiteralNegative ::= INTEGER_NEGATIVE | DECIMAL_NEGATIVE | DOUBLE_NEGATIVE
        {
          :finish => lambda { |data|
            num = data.values.flatten.last
            add_prod_datum(:literal, num.class.new("-#{num.value}"))
            add_prod_datum(:UnaryExpression, data[:UnaryExpression]) # Keep track of this for parent UnaryExpression production
          }
        }
      when :IRIref
        # [67]    IRIref ::= IRI_REF | PrefixedName
        {
          :finish => lambda { |data| add_prod_datum(:IRIref, data[:iri]) }
        }
      when :PrefixedName
        # [68]    PrefixedName ::= PNAME_LN | PNAME_NS
        {
          :finish => lambda { |data| add_prod_datum(:iri, data[:PrefixedName]) }
        }
      end
    end

    # Start for production
    def onStart(prod)
      context = contexts(prod.to_sym)
      @productions << prod
      if context
        # Create a new production data element, potentially allowing handler to customize before pushing on the @prod_data stack
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
      when :_Add_Sub_MultiplicativeExpression_Star
        case production
        when :"+", :"-"
          lambda { |token| add_prod_datum(:AdditiveExpression, production) }
        end
      when :UnaryExpression
        case production
        when :"!", :"+", :"-"
          lambda { |token| add_prod_datum(:UnaryExpression, production) }
        end
      when :NumericLiteralPositive, :NumericLiteralNegative, :NumericLiteral
        case production
        when :"+", :"-"
          lambda { |token| add_prod_datum(:NumericLiteral, production) }
        end
      else
        # Generic tokens that don't depend on a particular production
        case production
        when :a
          lambda { |token| add_prod_datum(:Verb, RDF_TYPE) }
        when :ANON
          lambda { |token| add_prod_datum(:BlankNode, gen_node()) }
        when :ASC, :DESC
          lambda { |token| add_prod_datum(:OrderDirection, token.downcase.to_sym) }
        when :BLANK_NODE_LABEL
          lambda { |token| add_prod_datum(:BlankNode, gen_node(token)) }
        when :BooleanLiteral
          lambda { |token|
            add_prod_datum(:literal, RDF::Literal.new(token, :datatype => RDF::XSD.boolean))
          }
        when :BOUND
          lambda { |token| add_prod_datum(:BOUND, :bound) }
        when :DATATYPE
          lambda { |token| add_prod_datum(:BuiltInCall, :datatype) }
        when :DECIMAL
          lambda { |token| add_prod_datum(:literal, RDF::Literal.new(token, :datatype => RDF::XSD.decimal)) }
        when :DISTINCT, :REDUCED
          lambda { |token| add_prod_datum(:DISTINCT_REDUCED, token.downcase.to_sym) }
        when :DOUBLE
          lambda { |token| add_prod_datum(:literal, RDF::Literal.new(token, :datatype => RDF::XSD.double)) }
        when :INTEGER
          lambda { |token| add_prod_datum(:literal, RDF::Literal.new(token, :datatype => RDF::XSD.integer)) }
        when :IRI_REF
          lambda { |token| add_prod_datum(:iri, uri(token)) }
        when :ISBLANK
          lambda { |token| add_prod_datum(:BuiltInCall, :isBLANK) }
        when :ISLITERAL
          lambda { |token| add_prod_datum(:BuiltInCall, :isLITERAL) }
        when :ISIRI
          lambda { |token| add_prod_datum(:BuiltInCall, :isIRI) }
        when :ISURI
          lambda { |token| add_prod_datum(:BuiltInCall, :isURI) }
        when :LANG
          lambda { |token| add_prod_datum(:BuiltInCall, :lang) }
        when :LANGMATCHES
          lambda { |token| add_prod_datum(:BuiltInCall, :langMatches) }
        when :LANGTAG
          lambda { |token| add_prod_datum(:language, token) }
        when :NIL
          lambda { |token| add_prod_datum(:NIL, RDF["nil"]) }
        when :PNAME_LN
          lambda { |token| add_prod_datum(:PrefixedName, ns(*token)) }
        when :PNAME_NS
          lambda { |token|
            add_prod_datum(:PrefixedName, ns(token, nil))    # [68] PrefixedName ::= PNAME_LN | PNAME_NS
            prod_data[:prefix] = token && token.to_sym      # [4]  PrefixDecl := 'PREFIX' PNAME_NS IRI_REF";
          }
        when :STR
          lambda { |token| add_prod_datum(:BuiltInCall, :str) }
        when :SAMETERM
          lambda { |token| add_prod_datum(:BuiltInCall, :sameTerm) }
        when :STRING_LITERAL1, :STRING_LITERAL2, :STRING_LITERAL_LONG1, :STRING_LITERAL_LONG2
          lambda { |token| add_prod_datum(:string, token) }
        when :VAR1, :VAR2       # [44]    Var ::= VAR1 | VAR2
          lambda { |token| add_prod_datum(:Var, variable(token, true)) }
        when :"*", :"/"
          lambda { |token| add_prod_datum(:MultiplicativeExpression, production) }
        when :"=", :"!=", :"<", :">", :"<=", :">="
          lambda { |token| add_prod_datum(:RelationalExpression, production) }
        when :"&&"
          lambda { |token| add_prod_datum(:ConditionalAndExpression, production) }
        when :"||"
          lambda { |token| add_prod_datum(:ConditionalOrExpression, production) }
        end
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

    # [1]     Query                     ::=       Prologue ( SelectQuery | ConstructQuery | DescribeQuery | AskQuery )
    #
    # Generate an S-Exp for the final query
    # Inputs are :BaseDecl, :PrefixDecl, and :query
    def finalize_query(data)
      return unless data[:query]

      query = data[:query].first

      query = Algebra::Expression[:prefix, data[:PrefixDecl].first, query] if data[:PrefixDecl]
      query = Algebra::Expression[:base, data[:BaseDecl].first, query] if data[:BaseDecl]
      add_prod_datum(:query, query)
    end

    # [40]    Collection ::= '(' GraphNode+ ')'
    #
    # Take collection of objects and create RDF Collection using rdf:first, rdf:rest and rdf:nil
    # @param [Hash] data Production Data
    def expand_collection(data)
      # Add any triples generated from deeper productions
      add_prod_datum(:pattern, data[:pattern])
      
      # Create list items for each element in data[:GraphNode]
      first = col = data[:Collection]
      list = data[:GraphNode].to_a.flatten.compact
      last = list.pop

      list.each do |r|
        add_pattern(:Collection, :subject => first, :predicate => RDF["first"], :object => r)
        rest = gen_node()
        add_pattern(:Collection, :subject => first, :predicate => RDF["rest"], :object => rest)
        first = rest
      end
      
      if last
        add_pattern(:Collection, :subject => first, :predicate => RDF["first"], :object => last)
      end
      add_pattern(:Collection, :subject => first, :predicate => RDF["rest"], :object => RDF["nil"])
    end

    # Class method version to aid in specs
    def self.variable(id, distinguished = true)
      Parser.new.send(:variable, id, distinguished)
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

    ##
    # @return [void]
    def fail
      false
    end
    alias_method :fail!, :fail

    # Flatten a Data in form of :filter => [op+ bgp?], without a query into filter and query creating exprlist, if necessary
    # @return [Array[:expr, query]]
    def flatten_filter(data)
      query = data.pop if data.last.respond_to?(:execute)
      expr = data.length > 1 ? Algebra::Operator::Exprlist.new(*data) : data.first
      [expr, query]
    end
    
    # Merge query modifiers, datasets, and projections
    def merge_modifiers(data)
      query = data[:query] ? data[:query].first : RDF::Query.new
      
      # Add datasets and modifiers in order
      query = Algebra::Expression[:order, data[:order].first, query] if data[:order]

      query = Algebra::Expression[:project, data[:Var], query] if data[:Var] # project

      query = Algebra::Expression[data[:DISTINCT_REDUCED].first, query] if data[:DISTINCT_REDUCED]

      query = Algebra::Expression[:slice, data[:slice][0], data[:slice][1], query] if data[:slice]
      
      query = Algebra::Expression[:dataset, data[:dataset], query] if data[:dataset]
      
      query
    end

    # Add joined expressions in for prod1 (op prod2)* to form (op (op 1 2) 3)
    def add_operator_expressions(production, data)
      # Iterate through expression to create binary operations
      res = data[:Expression]
      while data[production] && !data[production].empty?
        res = Algebra::Expression[data[production].shift + res + data[production].shift]
      end
      add_prod_datum(:Expression, res)
    end

    # Accumulate joined expressions in for prod1 (op prod2)* to form (op (op 1 2) 3)
    def accumulate_operator_expressions(operator, production, data)
      if data[operator]
        # Add [op data] to stack based on "production"
        add_prod_datum(production, [data[operator], data[:Expression]])
        # Add previous [op data] information
        add_prod_datum(production, data[production])
      else
        # No operator, forward :Expression
        add_prod_datum(:Expression, data[:Expression])
      end
    end

    # Add a single value to prod_data, allows for values to be an array
    def add_prod_datum(sym, values)
      case values
      when Array
        prod_data[sym] ||= []
        debug "add_prod_datum(#{sym})", "#{prod_data[sym].inspect} += #{values.inspect}"
        prod_data[sym] += values
      when nil
        return
      else
        prod_data[sym] ||= []
        debug "add_prod_datum(#{sym})", "#{prod_data[sym].inspect} << #{values.inspect}"
        prod_data[sym] << values
      end
    end
    
    # Add values to production data, values aranged as an array
    def add_prod_data(sym, *values)
      return if values.compact.empty?
      
      prod_data[sym] ||= []
      prod_data[sym] += values
      debug "add_prod_data(#{sym})", "#{prod_data[sym].inspect} += #{values.inspect}"
    end
    
    # Generate a BNode identifier
    def gen_node(id = nil)
      if @nd_var_gen
        # Use non-distinguished variables within patterns
        variable(id, false)
      else
        unless id
          id = @options[:anon_base]
          @options[:anon_base] = @options[:anon_base].succ
        end
        RDF::Node.new(id)
      end
    end
    
    ##
    # Return variable allocated to an ID.
    # If no ID is provided, a new variable
    # is allocated. Otherwise, any previous assignment will be used.
    #
    # The variable has a #distinguished? method applied depending on if this
    # is a disinguished or non-distinguished variable. Non-distinguished
    # variables are effectively the same as BNodes.
    # @return [RDF::Query::Variable]
    def variable(id, distinguished = true)
      id = nil if id.to_s.empty?
      
      if id
        @vars[id] ||= begin
          v = RDF::Query::Variable.new(id)
          v.distinguished = distinguished
          v
        end
      else
        unless distinguished
          # Allocate a non-distinguished variable identifier
          id = @nd_var_gen
          @nd_var_gen = id.succ
        end
        v = RDF::Query::Variable.new(id)
        v.distinguished = distinguished
        v
      end
    end
    
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
    
    def ns(prefix, suffix)
      base = prefix(prefix).to_s
      suffix = suffix.to_s.sub(/^\#/, "") if base.index("#")
      debug("ns(#{prefix.inspect})", "base: '#{base}', suffix: '#{suffix}'")
      uri = uri(base + suffix.to_s)
      # Cause URI to be serialized as a lexical
      uri.lexical = "#{prefix}:#{suffix}" unless options[:resolve_uris]
      uri
    end
    
    # add a pattern
    #
    # @param [String] production:: Production generating pattern
    # @param [RDF::Term] subject:: the subject of the pattern
    # @param [RDF::Term] predicate:: the predicate of the pattern
    # @param [RDF::Term, Node, Literal] object:: the object of the pattern
    def add_pattern(production, options)
      progress(production, "add_pattern: #{options.inspect}")
      progress(production, "[:pattern, #{options[:subject]}, #{options[:predicate]}, #{options[:object]}]")
      triple = {}
      options.each_pair do |r, v|
        if v.is_a?(Array) && v.flatten.length == 1
          v = v.flatten.first
        end
        if validate? && !v.is_a?(RDF::Term)
          error("add_pattern", "Expected #{r} to be a resource, but it was #{v.inspect}",
            :production => production)
        end
        triple[r] = v
      end
      add_prod_datum(:pattern, RDF::Query::Pattern.new(triple))
    end

    instance_methods.each { |method| public method } # DEBUG

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
