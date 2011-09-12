# coding: utf-8
$:.unshift ".."
require 'spec_helper'
require 'rdf/ll1/lexer'

describe RDF::LL1::Lexer do
  before(:all) do
    require 'rdf/turtle/terminals'

    @terminals = [
      [:ANON,                 RDF::Turtle::Terminals::ANON],
      [nil,                   %r([\(\),.;\[\]a]|\^\^|@base|@prefix|true|false)],
      [:BLANK_NODE_LABEL,     RDF::Turtle::Terminals::BLANK_NODE_LABEL],
      [:IRI_REF,              RDF::Turtle::Terminals::IRI_REF],
      [:DECIMAL,              RDF::Turtle::Terminals::DECIMAL],
      [:DECIMAL_NEGATIVE,     RDF::Turtle::Terminals::DECIMAL_NEGATIVE],
      [:DECIMAL_POSITIVE,     RDF::Turtle::Terminals::DECIMAL_POSITIVE],
      [:DOUBLE,               RDF::Turtle::Terminals::DOUBLE],
      [:DOUBLE_NEGATIVE,      RDF::Turtle::Terminals::DOUBLE_NEGATIVE],
      [:DOUBLE_POSITIVE,      RDF::Turtle::Terminals::DOUBLE_POSITIVE],
      [:INTEGER,              RDF::Turtle::Terminals::INTEGER],
      [:INTEGER_NEGATIVE,     RDF::Turtle::Terminals::INTEGER_NEGATIVE],
      [:INTEGER_POSITIVE,     RDF::Turtle::Terminals::INTEGER_POSITIVE],
      [:LANGTAG,              RDF::Turtle::Terminals::LANGTAG],
      [:PNAME_LN,             RDF::Turtle::Terminals::PNAME_LN],
      [:PNAME_NS,             RDF::Turtle::Terminals::PNAME_NS],
      [:STRING_LITERAL_LONG1, RDF::Turtle::Terminals::STRING_LITERAL_LONG1],
      [:STRING_LITERAL_LONG2, RDF::Turtle::Terminals::STRING_LITERAL_LONG2],
      [:STRING_LITERAL1,      RDF::Turtle::Terminals::STRING_LITERAL1],
      [:STRING_LITERAL2,      RDF::Turtle::Terminals::STRING_LITERAL2],
    ]
    
    @unescape_terms = [
      :IRI_REF, :STRING_LITERAL1, :STRING_LITERAL2, :STRING_LITERAL_LONG1, :STRING_LITERAL_LONG2
    ]
  end
  
  describe ".unescape_codepoints" do
    # @see http://www.w3.org/TR/rdf-sparql-query/#codepointEscape

    it "unescapes \\uXXXX codepoint escape sequences" do
      inputs = {
        %q(\\u0020)       => %q( ),
        %q(<ab\\u00E9xy>) => %Q(<ab\xC3\xA9xy>),
        %q(\\u03B1:a)     => %Q(\xCE\xB1:a),
        %q(a\\u003Ab)     => %Q(a\x3Ab),
      }
      inputs.each do |input, output|
        output.force_encoding(Encoding::UTF_8) if output.respond_to?(:force_encoding) # Ruby 1.9+
        RDF::LL1::Lexer.unescape_codepoints(input).should == output
      end
    end

    it "unescapes \\UXXXXXXXX codepoint escape sequences" do
      inputs = {
        %q(\\U00000020)   => %q( ),
        %q(\\U00010000)   => %Q(\xF0\x90\x80\x80),
        %q(\\U000EFFFF)   => %Q(\xF3\xAF\xBF\xBF),
      }
      inputs.each do |input, output|
        output.force_encoding(Encoding::UTF_8) if output.respond_to?(:force_encoding) # Ruby 1.9+
        RDF::LL1::Lexer.unescape_codepoints(input).should == output
      end
    end

    
    context "escaped strings" do
      {
        'Dürst' => 'D\\u00FCrst',
        "é" => '\\u00E9',
        "€" => '\\u20AC',
        "resumé" => 'resum\\u00E9',
      }.each_pair do |unescaped, escaped|
        it "unescapes #{unescaped.inspect}" do
          RDF::LL1::Lexer.unescape_codepoints(escaped).should == unescaped
        end
      end
    end
  end

  describe ".unescape_string" do
    # @see http://www.w3.org/TR/rdf-sparql-query/#grammarEscapes

    context "escape sequences" do
      RDF::LL1::Lexer::ESCAPE_CHARS.each do |escaped, unescaped|
        it "unescapes #{unescaped.inspect}" do
          RDF::LL1::Lexer.unescape_string(escaped).should == unescaped
        end
      end
    end
    
    context "escaped strings" do
      {
        'simple literal' => 'simple literal',
        'backslash:\\' => 'backslash:\\\\',
        'dquote:"' => 'dquote:\\"',
        "newline:\n" => 'newline:\\n',
        "return\r" => 'return\\r',
        "tab:\t" => 'tab:\\t',
      }.each_pair do |unescaped, escaped|
        it "unescapes #{unescaped.inspect}" do
          RDF::LL1::Lexer.unescape_string(escaped).should == unescaped
        end
      end
    end
  end

  describe ".tokenize" do
    describe "numeric literals" do
      it "tokenizes unsigned integer literals" do
        tokenize(%q(42)) do |tokens|
          tokens.should have(1).element
          tokens.first.type.should  == :INTEGER
          tokens.first.value.should == "42"
        end
      end

      it "tokenizes positive integer literals" do
        tokenize(%q(+42)) do |tokens|
          tokens.should have(1).element
          tokens.last.type.should  == :INTEGER_POSITIVE
          tokens.last.value.should == "+42"
        end
      end

      it "tokenizes negative integer literals" do
        tokenize(%q(-42)) do |tokens|
          tokens.should have(1).element
          tokens.last.type.should  == :INTEGER_NEGATIVE
          tokens.last.value.should == "-42"
        end
      end

      it "tokenizes unsigned decimal literals" do
        tokenize(%q(3.1415)) do |tokens|
          tokens.should have(1).element
          tokens.first.type.should  == :DECIMAL
          tokens.first.value.should == "3.1415"
        end
      end

      it "tokenizes positive decimal literals" do
        tokenize(%q(+3.1415)) do |tokens|
          tokens.should have(1).element
          tokens.last.type.should  == :DECIMAL_POSITIVE
          tokens.last.value.should == "+3.1415"
        end
      end

      it "tokenizes negative decimal literals" do
        tokenize(%q(-3.1415)) do |tokens|
          tokens.should have(1).element
          tokens.last.type.should  == :DECIMAL_NEGATIVE
          tokens.last.value.should == "-3.1415"
        end
      end

      it "tokenizes unsigned double literals" do
        tokenize(%q(1e6)) do |tokens|
          tokens.should have(1).element
          tokens.first.type.should  == :DOUBLE
          tokens.first.value.should == "1e6"
        end
      end

      it "tokenizes positive double literals" do
        tokenize(%q(+1e6)) do |tokens|
          tokens.should have(1).element
          tokens.last.type.should  == :DOUBLE_POSITIVE
          tokens.last.value.should == "+1e6"
        end
      end

      it "tokenizes negative double literals" do
        tokenize(%q(-1e6)) do |tokens|
          tokens.should have(1).element
          tokens.last.type.should  == :DOUBLE_NEGATIVE
          tokens.last.value.should == "-1e6"
        end
      end
    end

    describe "string literals" do
      it "tokenizes single-quoted string literals" do
        tokenize(%q('Hello, world!')) do |tokens|
          tokens.should have(1).element
          tokens.first.type.should  == :STRING_LITERAL1
          tokens.first.value.should == %q('Hello, world!')
        end
      end

      it "tokenizes double-quoted string literals" do
        tokenize(%q("Hello, world!")) do |tokens|
          tokens.should have(1).element
          tokens.first.type.should  == :STRING_LITERAL2
          tokens.first.value.should == %q("Hello, world!")
        end
      end

      it "tokenizes long single-quoted string literals" do
        tokenize(%q('''Hello, world!''')) do |tokens|
          tokens.should have(1).element
          tokens.first.type.should  == :STRING_LITERAL_LONG1
          tokens.first.value.should == %q('''Hello, world!''')
        end
      end

      it "tokenizes long double-quoted string literals" do
        tokenize(%q("""Hello, world!""")) do |tokens|
          tokens.should have(1).element
          tokens.first.type.should  == :STRING_LITERAL_LONG2
          tokens.first.value.should == %q("""Hello, world!""")
        end
      end
    end

    describe "blank nodes" do
      it "tokenizes labelled blank nodes" do
        tokenize(%q(_:foobar)) do |tokens|
          tokens.should have(1).element
          tokens.first.type.should  == :BLANK_NODE_LABEL
          tokens.first.value.should == "_:foobar"
        end
      end

      it "tokenizes anonymous blank nodes" do
        ['[]', '[ ]'].each do |anon|
          tokenize(anon) do |tokens|
            tokens.should have(1).element
            tokens.first.type.should  == :ANON
            tokens.first.value.should == anon
          end
        end
      end
    end

    describe "IRI_REF" do
      it "tokenizes absolute IRI references" do
        tokenize(%q(<http://example.org/foobar>)) do |tokens|
          tokens.should have(1).element
          tokens.first.type.should  == :IRI_REF
          tokens.first.value.should == '<http://example.org/foobar>'
        end
      end

      it "tokenizes relative IRI references" do
        tokenize(%q(<foobar>)) do |tokens|
          tokens.should have(1).element
          tokens.first.type.should  == :IRI_REF
          tokens.first.value.should == '<foobar>'
        end
      end
    end

    describe "PNAME_NS" do
      it "tokenizes the empty prefix" do
        tokenize(%q(:)) do |tokens|
          tokens.should have(1).element
          tokens.first.type.should  == :PNAME_NS
          tokens.first.value.should == ':'
        end
      end

      it "tokenizes labelled prefixes" do
        tokenize(%q(dc:)) do |tokens|
          tokens.should have(1).element
          tokens.first.type.should  == :PNAME_NS
          tokens.first.value.should == "dc:"
        end
      end
    end

    describe "PNAME_LN" do
      it "tokenizes prefixed names" do
        tokenize(%q(dc:title)) do |tokens|
          tokens.should have(1).element
          tokens.first.type.should == :PNAME_LN
          tokens.first.value.should == "dc:title"
        end
      end

      it "prefixed names having an empty prefix label" do
        tokenize(%q(:title)) do |tokens|
          tokens.should have(1).element
          tokens.first.type.should == :PNAME_LN
          tokens.first.value.should == ":title"
        end
      end
    end

    describe "RDF literals" do
      it "tokenizes language-tagged literals" do
        tokenize(%q("Hello, world!"@en)) do |tokens|
          tokens.should have(2).elements
          tokens[0].type.should  == :STRING_LITERAL2
          tokens[0].value.should == '"Hello, world!"'
          tokens[1].type.should  == :LANGTAG
          tokens[1].value.should == "@en"
        end
        tokenize(%q("Hello, world!"@en-US)) do |tokens|
          tokens.should have(2).elements
          tokens[0].type.should  == :STRING_LITERAL2
          tokens[0].value.should == '"Hello, world!"'
          tokens[1].type.should  == :LANGTAG
          tokens[1].value.should == '@en-US'
        end
      end
      
      it "tokenizes multiple string literals" do
        tokenize(%q("1", "2")) do |tokens|
          tokens.should have(3).elements
          tokens[0].type.should  == :STRING_LITERAL2
          tokens[0].value.should == '"1"'
          tokens[1].type.should  == nil
          tokens[1].value.should == ','
          tokens[2].type.should  == :STRING_LITERAL2
          tokens[2].value.should == '"2"'
        end
      end

      it "datatyped literals" do
        tokenize(%q('3.1415'^^<http://www.w3.org/2001/XMLSchema#double>)) do |tokens|
          tokens.should have(3).elements
          tokens[0].type.should  == :STRING_LITERAL1
          tokens[0].value.should == "'3.1415'"
          tokens[1].type.should  == nil
          tokens[1].value.should == '^^'
          tokens[2].type.should  == :IRI_REF
          tokens[2].value.should == "<#{RDF::XSD.double}>"
        end

        tokenize(%q("3.1415"^^<http://www.w3.org/2001/XMLSchema#double>)) do |tokens|
          tokens.should have(3).elements
          tokens[0].type.should  == :STRING_LITERAL2
          tokens[0].value.should == '"3.1415"'
          tokens[1].type.should  == nil
          tokens[1].value.should == '^^'
          tokens[2].type.should  == :IRI_REF
          tokens[2].value.should == "<#{RDF::XSD.double}>"
        end
      end
    end

    describe "string terminals" do
      %w|^^ ( ) [ ] , ; . a true false @base @prefix|.each do |string|
        it "tokenizes the #{string.inspect} string" do
          tokenize(string) do |tokens|
            tokens.should have(1).element
            tokens.first.type.should  == nil
            tokens.first.value.should == string
          end
        end
      end
    end

    describe "comments" do
      it "ignores the remainder of the current line" do
        tokenize("# :foo :bar", "# :foo :bar\n", "# :foo :bar\r\n") do |tokens|
          tokens.should have(0).elements
        end
      end

      it "ignores leading whitespace" do
        tokenize(" # :foo :bar", "\n# :foo :bar", "\r\n# :foo :bar") do |tokens|
          tokens.should have(0).elements
        end
      end

      it "resumes tokenization from the following line" do
        tokenize("# :foo\n:bar", "# :foo\r\n:bar") do |tokens|
          tokens.should have(1).elements
          tokens.first.type.should  == :PNAME_LN
          tokens.first.value.should == ":bar"
        end
      end
    end

    describe "white space" do
      it "tracks the current line number" do
        inputs = {
          ""     => 1,
          "\n"   => 2,
          "\n\n" => 3,
          "\r\n" => 2,
        }
        inputs.each do |input, lineno|
          lexer = RDF::LL1::Lexer.tokenize(input, @terminals, :unescape_terms => @unescape_terms)
          lexer.to_a # consumes the input
          lexer.lineno.should == lineno
        end
      end
    end

    describe "yielding tokens" do
      it "annotates tokens with the current line number" do
        results = %w(1 2 3 4)
        RDF::LL1::Lexer.tokenize("1\n2\n3\n4", @terminals, :unescape_terms => @unescape_terms).each_token do |token|
          token.type.should == :INTEGER
          token.value.should == results.shift
        end
      end
    end

    describe "invalid input" do
      it "raises a lexer error" do
        lambda { tokenize("SELECT foo WHERE {}") }.should raise_error(RDF::LL1::Lexer::Error)
      end

      it "reports the invalid token which triggered the error" do
        begin
          tokenize("@prefix foo <>")
        rescue RDF::LL1::Lexer::Error => error
          error.token.should  == 'foo'
        end
        begin
          tokenize("@prefix foo: <>\n@prefix") {}
        rescue RDF::LL1::Lexer::Error => error
          error.token.should  == '@base'
        end
      end

      it "reports the line number where the error occurred" do
        begin
          tokenize("@prefix foo <>")
        rescue RDF::LL1::Lexer::Error => error
          error.lineno.should == 1
        end
        begin
          tokenize("@prefix\nfoo <>")
        rescue RDF::LL1::Lexer::Error => error
          error.lineno.should == 2
        end
      end
    end
    
    describe "reader tests" do
      {
        :bbc => %q(
          @prefix dc: <http://purl.org/dc/elements/1.1/>.
          @prefix po: <http://purl.org/ontology/po/>.
          @prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>.
          _:broadcast
           a po:Broadcast;
           po:schedule_date """2008-06-24T12:00:00Z""";
           po:broadcast_of _:version;
           po:broadcast_on <http://www.bbc.co.uk/programmes/service/6music>;
          .
          _:version
           a po:Version;
          .
          <http://www.bbc.co.uk/programmes/b0072l93>
           dc:title """Nemone""";
           a po:Brand;
          .
          <http://www.bbc.co.uk/programmes/b00c735d>
           a po:Episode;
           po:episode <http://www.bbc.co.uk/programmes/b0072l93>;
           po:version _:version;
           po:long_synopsis """Actor and comedian Rhys Darby chats to Nemone.""";
           dc:title """Nemone""";
           po:synopsis """Actor and comedian Rhys Darby chats to Nemone.""";
          .
          <http://www.bbc.co.uk/programmes/service/6music>
           a po:Service;
           dc:title """BBC 6 Music""";
          .

          #_:abcd a po:Episode.
        ),
        "muti-line" => %q(
          :a :b """Foo
          <html:b xmlns:html="http://www.w3.org/1999/xhtml" html:a="b">
            bar
            <rdf:Thing xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#">
              <a:b xmlns:a="foo:"></a:b>
              here
              <a:c xmlns:a="foo:"></a:c>
            </rd
            f:Thing>
          </html:b>
          baz
          <html:i xmlns:html="http://www.w3.org/1999/xhtml">more</html:i>"""
        ),
        'simple literal' => ':a :b  "simple literal" .',
        'backslash:\\' => ':a :b  "backslash:\\\\" .',
        'dquote:"' => ':a :b  "dquote:\\"" .',
        "newline:\n" => ':a :b  "newline:\\n" .',
        "return\r" => ':a :b  "return\\r" .',
        "tab:\t" => ':a :b  "tab:\\t" .',
        'Dürst' => ':a :b "Dürst" .',
        "é" => ':a :b  "é" .',
        "€" => ':a :b  "€" .',
        "resumé" => ':a :resume  "resumé" .',
      }.each do |test, input|
        it "tokenizes #{test}" do
          tokenize(input) do |tokens|
            tokens.should_not be_empty
          end
        end
      end
    end
  end

  def tokenize(*inputs, &block)
    options = inputs.last.is_a?(Hash) ? inputs.pop : {}
    inputs.each do |input|
      tokens = RDF::LL1::Lexer.tokenize(input, @terminals, :unescape_terms => @unescape_terms)
      tokens.should be_a(RDF::LL1::Lexer)
      block.call(tokens.to_a)
    end
  end
end
