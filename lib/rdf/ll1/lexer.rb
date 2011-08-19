require 'strscan'    unless defined?(StringScanner)
require 'bigdecimal' unless defined?(BigDecimal)

module RDF::LL1
  ##
  # A lexical analyzer
  #
  # @example Tokenizing a Turtle string
  #   terminals = [
  #     [:BLANK_NODE_LABEL, %r(_:(#{PN_LOCAL}))],
  #     ...
  #   ]
  #   ttl = "@prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> ."
  #   lexer = RDF::LL1::Lexer.tokenize(ttl, terminals)
  #   lexer.each_token do |token|
  #     puts token.inspect
  #   end
  #
  # @example Tokenizing and returning a token stream
  #   lexer = RDF::LL1::Lexer.tokenize(...)
  #   while :some-condition
  #     token = lexer.first # Get the current token
  #     token = lexer.shift # Get the current token and shift to the next
  #   end
  #
  # @example Handling error conditions
  #   begin
  #     RDF::Turtle::Lexer.tokenize(query)
  #   rescue RDF::Turtle::Lexer::Error => error
  #     warn error.inspect
  #   end
  #
  # @see http://en.wikipedia.org/wiki/Lexical_analysis
  class Lexer
    include Enumerable

    ESCAPE_CHARS         = {
      '\t'   => "\t",    # \u0009 (tab)
      '\n'   => "\n",    # \u000A (line feed)
      '\r'   => "\r",    # \u000D (carriage return)
      '\b'   => "\b",    # \u0008 (backspace)
      '\f'   => "\f",    # \u000C (form feed)
      '\\"'  => '"',     # \u0022 (quotation mark, double quote mark)
      '\\\'' => '\'',    # \u0027 (apostrophe-quote, single quote mark)
      '\\\\' => '\\'     # \u005C (backslash)
    }
    ESCAPE_CHAR4         = /\\u([0-9A-Fa-f]{4,4})/                              # \uXXXX
    ESCAPE_CHAR8         = /\\U([0-9A-Fa-f]{8,8})/                              # \UXXXXXXXX
    ECHAR                = /\\[tbnrf\\"']/                                      # [91s]
    UCHAR               = /#{ESCAPE_CHAR4}|#{ESCAPE_CHAR8}/
    COMMENT              = /#.*/
    WS                   = /\x20|\x09|\x0D|\x0A/

    ##
    # @attr [Regexp] defines whitespace, defaults to WS
    attr_reader :whitespace

    ##
    # @attr [Regexp] defines single-line comment, defaults to COMMENT
    attr_reader :comment

    ##
    # Returns a copy of the given `input` string with all `\uXXXX` and
    # `\UXXXXXXXX` Unicode codepoint escape sequences replaced with their
    # unescaped UTF-8 character counterparts.
    #
    # @param  [String] input
    # @return [String]
    # @see    http://www.w3.org/TR/rdf-sparql-query/#codepointEscape
    def self.unescape_codepoints(input)
      string = input.dup
      string.force_encoding(Encoding::ASCII_8BIT) if string.respond_to?(:force_encoding) # Ruby 1.9+

      # Decode \uXXXX and \UXXXXXXXX code points:
      string.gsub!(UCHAR) do
        s = [($1 || $2).hex].pack('U*')
        s.respond_to?(:force_encoding) ? s.force_encoding(Encoding::ASCII_8BIT) : s
      end

      string.force_encoding(Encoding::UTF_8) if string.respond_to?(:force_encoding)      # Ruby 1.9+
      string
    end

    ##
    # Returns a copy of the given `input` string with all string escape
    # sequences (e.g. `\n` and `\t`) replaced with their unescaped UTF-8
    # character counterparts.
    #
    # @param  [String] input
    # @return [String]
    # @see    http://www.w3.org/TR/rdf-sparql-query/#grammarEscapes
    def self.unescape_string(input)
      input.gsub(ECHAR) { |escaped| ESCAPE_CHARS[escaped] }
    end

    ##
    # Tokenizes the given `input` string or stream.
    #
    # @param  [String, #to_s]                 input
    # @param  [Array<Array<Symbol, Regexp>>]  terminals
    #   Array of symbol, regexp pairs used to match terminals.
    #   If the symbol is nil, it defines a Regexp to match string terminals.
    # @param  [Hash{Symbol => Object}]        options
    # @yield  [lexer]
    # @yieldparam [Lexer] lexer
    # @return [Lexer]
    # @raise  [Lexer::Error] on invalid input
    def self.tokenize(input, terminals, options = {}, &block)
      lexer = self.new(input, terminals, options)
      block_given? ? block.call(lexer) : lexer
    end

    ##
    # Initializes a new lexer instance.
    #
    # @param  [String, #to_s]                 input
    # @param  [Array<Array<Symbol, Regexp>>]  terminals
    #   Array of symbol, regexp pairs used to match terminals.
    #   If the symbol is nil, it defines a Regexp to match string terminals.
    # @param  [Hash{Symbol => Object}]        options
    # @option options [Regexp]                :whitespace (WS)
    # @option options [Regexp]                :comment (COMMENT)
    def initialize(input = nil, terminals = nil, options = {})
      @options = options.dup
      @whitespace = @options[:whitespace] || WS
      @comment = @options[:comment] || COMMENT
      @terminals = terminals

      raise Error, "Terminal patterns not defined" unless @terminals && @terminals.length > 0

      self.input = input if input
    end

    ##
    # Any additional options for the lexer.
    #
    # @return [Hash]
    attr_reader   :options

    ##
    # The current input string being processed.
    #
    # @return [String]
    attr_accessor :input

    ##
    # The current line number (zero-based).
    #
    # @return [Integer]
    attr_reader   :lineno

    ##
    # @param  [String, #to_s] input
    # @return [void]
    def input=(input)
      @input = case input
        when ::String     then input
        when IO, StringIO then input.read
        else input.to_s
      end
      @input = self.class.unescape_codepoints(@input) if UCHAR === @input
      @lineno = 1
      @scanner = StringScanner.new(@input)
    end

    ##
    # Returns `true` if the input string is lexically valid.
    #
    # To be considered valid, the input string must contain more than zero
    # tokens, and must not contain any invalid tokens.
    #
    # @return [Boolean]
    def valid?
      begin
        !count.zero?
      rescue Error
        false
      end
    end

    ##
    # Enumerates each token in the input string.
    #
    # @yield  [token]
    # @yieldparam [Token] token
    # @return [Enumerator]
    def each_token(&block)
      if block_given?
        while token = shift
          yield token
        end
      end
      enum_for(:each_token)
    end
    alias_method :each, :each_token

    ##
    # Returns first token in input stream
    #
    # @return [Token]
    def first
      return nil unless scanner

      if @first.nil?
        {} while !scanner.eos? && (skip_whitespace)
        return @scanner = nil if scanner.eos?

        @first = match_token

        if @first.nil?
          lexme = (@scanner.rest.split(/#{@whitespace}|#{@comment}/).first rescue nil) || @scanner.rest
          raise Error.new("Invalid token #{lexme.inspect} on line #{lineno + 1}",
            :input => input, :token => lexme, :lineno => lineno)
        end
      end

      @first
    end

    ##
    # Returns first token and shifts to next
    #
    # @return [Token]
    def shift
      cur = first
      @first = nil
      cur
    end
    
  protected

    # @return [StringScanner]
    attr_reader :scanner

    ##
    # Skip whitespace or comments, as defined through input options or defaults
    def skip_whitespace
      # skip all white space, but keep track of the current line number
      while !scanner.eos?
        if matched = scanner.scan(@whitespace)
          @lineno += matched.count("\n")
        elsif scanner.skip(@comment)
        else
          return
        end
      end
    end

    def match_token
      @terminals.each do |(term, regexp)|
        if matched = scanner.scan(regexp)
          return token(term, matched, scanner)
        end
      end
      nil
    end

  protected

    ##
    # Constructs a new token object annotated with the current line number.
    #
    # The parser relies on the type being a symbolized URI and the value being
    # a string, if there is no type. If there is a type, then the value takes
    # on the native representation appropriate for that type.
    #
    # @param  [Symbol] type
    # @param  [String] value
    # @param  [StringScanner] scanner
    #   Scanner instance with access to matched groups
    # @return [Token]
    def token(type, value, scanner)
      Token.new(type, value, scanner, :lineno => lineno)
    end

    ##
    # Represents a lexer token.
    #
    # @example Creating a new token
    #   token = RDF::LL1::Lexer::Token.new(:LANGTAG, "en")
    #   token.type   #=> :LANGTAG
    #   token.value  #=> "en"
    #
    # @see http://en.wikipedia.org/wiki/Lexical_analysis#Token
    class Token
      ##
      # Initializes a new token instance.
      #
      # @param  [Symbol]                 type
      # @param  [String]              value
      # @param  [Hash{Symbol => Object}] options
      # @option options [Integer]        :lineno (nil)
      def initialize(type, value, scanner, options = {})
        @type, @value, @scanner = (type ? type.to_s.to_sym : nil), value, scanner.dup
        @options = options.dup
        @lineno  = @options.delete(:lineno)
      end

      ##
      # The token's symbol type.
      #
      # @return [Symbol]
      attr_reader :type

      ##
      # The token's value.
      #
      # @return [String]
      attr_reader :value

      ##
      # The scanner at time of match, for access to matched group patterns.
      #
      # @return [StringScanner]
      attr_reader :scanner

      ##
      # The line number where the token was encountered.
      #
      # @return [Integer]
      attr_reader :lineno

      ##
      # Any additional options for the token.
      #
      # @return [Hash]
      attr_reader :options

      ##
      # Returns the attribute named by `key`.
      #
      # @param  [Symbol] key
      # @return [Object]
      def [](key)
        key = key.to_s.to_sym unless key.is_a?(Integer) || key.is_a?(Symbol)
        case key
          when 0, :type  then @type
          when 1, :value then @value
          else nil
        end
      end

      ##
      # Returns `true` if the given `value` matches either the type or value
      # of this token.
      #
      # @example Matching using the symbolic type
      #   SPARQL::Grammar::Lexer::Token.new(:NIL) === :NIL     #=> true
      #
      # @example Matching using the string value
      #   SPARQL::Grammar::Lexer::Token.new(nil, "{") === "{"  #=> true
      #
      # @param  [Symbol, String] value
      # @return [Boolean]
      def ===(value)
        case value
          when Symbol   then value == @type
          when ::String then value.to_s == @value.to_s
          else value == @value
        end
      end

      ##
      # Returns a hash table representation of this token.
      #
      # @return [Hash]
      def to_hash
        {:type => @type, :value => @value}
      end
      
      ##
      # Readable version of token
      def to_s
        @type ? @type.inspect : @value
      end

      ##
      # Returns type, if not nil, otherwise value
      def representation
        @type ? @type : @value
      end

      ##
      # Returns an array representation of this token.
      #
      # @return [Array]
      def to_a
        [@type, @value]
      end

      ##
      # Returns a developer-friendly representation of this token.
      #
      # @return [String]
      def inspect
        to_hash.inspect
      end
    end # class Token

    ##
    # Raised for errors during lexical analysis.
    #
    # @example Raising a lexer error
    #   raise SPARQL::Grammar::Lexer::Error.new(
    #     "invalid token '%' on line 10",
    #     :input => query, :token => '%', :lineno => 9)
    #
    # @see http://ruby-doc.org/core/classes/StandardError.html
    class Error < StandardError
      ##
      # The input string associated with the error.
      #
      # @return [String]
      attr_reader :input

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
      # @option options [String]         :input  (nil)
      # @option options [String]         :token  (nil)
      # @option options [Integer]        :lineno (nil)
      def initialize(message, options = {})
        @input  = options[:input]
        @token  = options[:token]
        @lineno = options[:lineno]
        super(message.to_s)
      end
    end # class Error
  end # class Lexer
end # module RDF::Turtle
