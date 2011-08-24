require 'strscan'    unless defined?(StringScanner)

module RDF::LL1
  ##
  # Overload StringScanner with file operations
  #
  # Reloads scanner as required until EOF.
  #
  # FIXME: Only implements the subset required by the Lexer for now.
  #
  # Reload happens either when scanner is at EOS
  # or if the beginning of the scanner contains specific
  # multi-line token start characters, and #match is called
  # with a multi-line Regexp
  class Scanner < StringScanner
    ##
    # @attr [IO, StringIO]
    attr_reader :input

    ##
    # @attr [Regexp]
    #   Regular expression matching the start of a multi-line token.
    #   Used to match against multi-line expressions to cause
    #   scanner to add lines to the buffer to match multi-line expressions.
    attr_accessor :ml_start

    ##
    # Open the file or stream for scanning
    #
    # @param [String, IO, #read] file
    # @param [Hash{Symbol => Object}] options
    # @option options [Regexp] :ml_start (nil)
    #   Regular expression matching the beginning of multi-line tokens.
    def self.open(file, options = {})
      scanner = new("")
      scanner.input = file
      scanner.ml_start = options[:ml_start]
      scanner
    end

    ##
    # Set input file
    # @param [String, IO, #read] file
    def input=(file)
      @input = case file
      when IO, StringIO
        file
      else
        if file.respond_to?(:read)
          file
        else
          File.open(file)
        end
      end
      self << @input.gets unless @input.eof?
    end

    ##
    # Returns `true` if the scan pointer is at the end of the file.
    #
    # @return [Boolean]
    def eos?
      super && (@input.nil? || @input.eof?)
    end
    
    ##
    # Returns the "rest" of the line, or the next line if at EOL (i.e. everything after the scan pointer).
    # If there is no more data (eos? = true), it returns "".
    #
    # @return [String]
    def rest
      return "" if eos?
      self << @input.gets if @input && !@input.eof? && rest_size == 0
      super
    end
    
    ##
    # Attempts to skip over the given `pattern` beginning with the scan pointer.
    # If it matches, the scan pointer is advanced to the end of the match,
    # and the length of the match is returned. Otherwise, `nil` is returned.
    #
    # It’s similar to {scan}, but without returning the matched string.
    # @param [Regexp] pattern
    def skip(pattern)
      str = scan(pattern)
      str.to_s.empty? ? nil : str.to_s.length
    end
    
    ##
    # Tries to match with `pattern` at the current position.
    #
    # If there’s a match, the scanner advances the "scan pointer" and returns the matched string.
    # Otherwise, the scanner returns nil.
    #
    # If the scanner begins with the multi-line start expression
    # @example
    #     s = StringScanner.new('test string')
    #     p s.scan(/\w+/)   # -> "test"
    #     p s.scan(/\w+/)   # -> nil
    #     p s.scan(/\s+/)   # -> " "
    #     p s.scan(/\w+/)   # -> "string"
    #     p s.scan(/./)     # -> nil
    #
    # @param [Regexp] pattern
    # @return [String]
    def scan(pattern)
      if (pattern.options & Regexp::MULTILINE) &&
        ml_start &&
        (md = pattern.source.match(ml_start)) &&
        rest[0, md.to_s.length] == md.to_s
        # Continue loading the buffer until the scan succeeds.
        # Note: this can cause the rest of the file to be read on a syntax error
        while !match?(pattern) && !input.eof
          self << input.gets
        end
      else
        self << input.gets if input && !input.eof? && rest_size == 0
      end
      
      super
    end
  end
end