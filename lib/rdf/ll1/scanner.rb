require 'strscan'    unless defined?(StringScanner)

module RDF::LL1
  ##
  # Overload StringScanner with file operations
  #
  # FIXME: Only implements the subset required by the Lexer for now.
  #
  # Reloads scanner as required until EOF.
  # * Loads to a high-water and reloads when remaining size reaches a low-water.
  class Scanner < StringScanner
    HIGH_WATER = 10240
    LOW_WATER  = 2048     # Hopefully large enough to deal with long multi-line comments

    ##
    # @attr [IO, StringIO]
    attr_reader :input

    ##
    # Open the file or stream for scanning
    #
    # @param [String, IO, #read] file
    # @param [Hash{Symbol => Object}] options
    # @option options[Integer] :high_water (HIGH_WATER)
    # @option options[Integer] :low_water (LOW_WATER)
    # @yield [string]
    # @yieldparam [String] string data read from input file
    # @yieldreturn [String] replacement read data, useful for decoding escapes.
    # @return [Scanner]
    def self.open(file, options = {}, &block)
      scanner = new("")
      scanner.set_input(file, options.merge(:high_water => HIGH_WATER, :low_water => LOW_WATER), &block)
      scanner
    end

    ##
    # Set input file
    # @param [String, IO, #read] file
    def set_input(file, options = {}, &block)
      @block = block

      @options = options
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
      feed_me
    end

    ##
    # Returns the "rest" of the line, or the next line if at EOL (i.e. everything after the scan pointer).
    # If there is no more data (eos? = true), it returns "".
    #
    # @return [String]
    def rest
      feed_me
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
      feed_me
      super
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
      feed_me
      super
    end
    
  private
    # Maintain low-water mark
    def feed_me
      if rest_size < @options[:low_water] && @input && !@input.eof?
        # Read up to high-water mark ensuring we're at an end of line
        diff = @options[:high_water] - rest_size
        string = @input.read(diff)
        string << @input.gets unless @input.eof?
        string = @block.call(string) if @block
        self << string
      end
    end
  end
end