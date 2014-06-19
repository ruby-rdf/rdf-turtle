# coding: utf-8
$:.unshift ".."
require 'spec_helper'
require 'ebnf/ll1/lexer'

describe EBNF::LL1::Lexer do
  before(:all) do
    require 'rdf/turtle/terminals'

    @terminals = [
      [:ANON,                 RDF::Turtle::Terminals::ANON],
      [nil,                   %r([\(\),.;\[\]a]|\^\^|@base|@prefix|true|false)],
      [:BLANK_NODE_LABEL,     RDF::Turtle::Terminals::BLANK_NODE_LABEL],
      [:IRIREF,               RDF::Turtle::Terminals::IRIREF],
      [:DECIMAL,              RDF::Turtle::Terminals::DECIMAL],
      [:DOUBLE,               RDF::Turtle::Terminals::DOUBLE],
      [:INTEGER,              RDF::Turtle::Terminals::INTEGER],
      [:LANGTAG,              RDF::Turtle::Terminals::LANGTAG],
      [:PNAME_LN,             RDF::Turtle::Terminals::PNAME_LN],
      [:PNAME_NS,             RDF::Turtle::Terminals::PNAME_NS],
      [:STRING_LITERAL_LONG_SINGLE_QUOTE, RDF::Turtle::Terminals::STRING_LITERAL_LONG_SINGLE_QUOTE],
      [:STRING_LITERAL_LONG_QUOTE, RDF::Turtle::Terminals::STRING_LITERAL_LONG_QUOTE],
      [:STRING_LITERAL_QUOTE,      RDF::Turtle::Terminals::STRING_LITERAL_QUOTE],
      [:STRING_LITERAL_SINGLE_QUOTE,      RDF::Turtle::Terminals::STRING_LITERAL_SINGLE_QUOTE],
    ]
    
    @unescape_terms = [
      :IRIREF, :STRING_LITERAL_QUOTE, :STRING_LITERAL_SINGLE_QUOTE, :STRING_LITERAL_LONG_SINGLE_QUOTE, :STRING_LITERAL_LONG_QUOTE
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
        output.force_encoding(Encoding::UTF_8)
        expect(EBNF::LL1::Lexer.unescape_codepoints(input)).to eq output
      end
    end

    it "unescapes \\UXXXXXXXX codepoint escape sequences" do
      inputs = {
        %q(\\U00000020)   => %q( ),
        %q(\\U00010000)   => %Q(\xF0\x90\x80\x80),
        %q(\\U000EFFFF)   => %Q(\xF3\xAF\xBF\xBF),
      }
      inputs.each do |input, output|
        output.force_encoding(Encoding::UTF_8)
        expect(EBNF::LL1::Lexer.unescape_codepoints(input)).to eq output
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
          expect(EBNF::LL1::Lexer.unescape_codepoints(escaped)).to eq unescaped
        end
      end
    end
  end

  describe ".unescape_string" do
    # @see http://www.w3.org/TR/rdf-sparql-query/#grammarEscapes

    context "escape sequences" do
      EBNF::LL1::Lexer::ESCAPE_CHARS.each do |escaped, unescaped|
        it "unescapes #{unescaped.inspect}" do
          expect(EBNF::LL1::Lexer.unescape_string(escaped)).to eq unescaped
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
          expect(EBNF::LL1::Lexer.unescape_string(escaped)).to eq unescaped
        end
      end
    end
  end

  describe ".tokenize" do
    describe "numeric literals" do
      it "tokenizes unsigned integer literals" do
        tokenize(%q(42)) do |tokens|
          expect(tokens.size).to eql 1
          expect(tokens.first.type).to eq :INTEGER
          expect(tokens.first.value).to eq "42"
        end
      end

      it "tokenizes positive integer literals" do
        tokenize(%q(+42)) do |tokens|
          expect(tokens.size).to eq 1
          expect(tokens.last.type).to eq :INTEGER
          expect(tokens.last.value).to eq "+42"
        end
      end

      it "tokenizes negative integer literals" do
        tokenize(%q(-42)) do |tokens|
          expect(tokens.size).to eql 1
          expect(tokens.last.type).to eq :INTEGER
          expect(tokens.last.value).to eq "-42"
        end
      end

      it "tokenizes unsigned decimal literals" do
        tokenize(%q(3.1415)) do |tokens|
          expect(tokens.size).to eql 1
          expect(tokens.first.type).to eq :DECIMAL
          expect(tokens.first.value).to eq "3.1415"
        end
      end

      it "tokenizes positive decimal literals" do
        tokenize(%q(+3.1415)) do |tokens|
          expect(tokens.size).to eql 1
          expect(tokens.last.type).to eq :DECIMAL
          expect(tokens.last.value).to eq "+3.1415"
        end
      end

      it "tokenizes negative decimal literals" do
        tokenize(%q(-3.1415)) do |tokens|
          expect(tokens.size).to eql 1
          expect(tokens.last.type).to eq :DECIMAL
          expect(tokens.last.value).to eq "-3.1415"
        end
      end

      it "tokenizes unsigned double literals" do
        tokenize(%q(1e6)) do |tokens|
          expect(tokens.size).to eql 1
          expect(tokens.first.type).to eq :DOUBLE
          expect(tokens.first.value).to eq "1e6"
        end
      end

      it "tokenizes positive double literals" do
        tokenize(%q(+1e6)) do |tokens|
          expect(tokens.size).to eql 1
          expect(tokens.last.type).to eq :DOUBLE
          expect(tokens.last.value).to eq "+1e6"
        end
      end

      it "tokenizes negative double literals" do
        tokenize(%q(-1e6)) do |tokens|
          expect(tokens.size).to eql 1
          expect(tokens.last.type).to eq :DOUBLE
          expect(tokens.last.value).to eq "-1e6"
        end
      end
    end

    describe "string literals" do
      it "tokenizes single-quoted string literals" do
        tokenize(%q('Hello, world!')) do |tokens|
          expect(tokens.size).to eql 1
          expect(tokens.first.type).to eq :STRING_LITERAL_SINGLE_QUOTE
          expect(tokens.first.value).to eq %q('Hello, world!')
        end
      end

      it "tokenizes double-quoted string literals" do
        tokenize(%q("Hello, world!")) do |tokens|
          expect(tokens.size).to eql 1
          expect(tokens.first.type).to eq :STRING_LITERAL_QUOTE
          expect(tokens.first.value).to eq %q("Hello, world!")
        end
      end

      it "tokenizes long single-quoted string literals" do
        tokenize(%q('''Hello, world!''')) do |tokens|
          expect(tokens.size).to eql 1
          expect(tokens.first.type).to eq :STRING_LITERAL_LONG_SINGLE_QUOTE
          expect(tokens.first.value).to eq %q('''Hello, world!''')
        end
      end

      it "tokenizes long double-quoted string literals" do
        tokenize(%q("""Hello, world!""")) do |tokens|
          expect(tokens.size).to eql 1
          expect(tokens.first.type).to eq :STRING_LITERAL_LONG_QUOTE
          expect(tokens.first.value).to eq %q("""Hello, world!""")
        end
      end
    end

    describe "blank nodes" do
      it "tokenizes labelled blank nodes" do
        tokenize(%q(_:foobar)) do |tokens|
          expect(tokens.size).to eql 1
          expect(tokens.first.type).to eq :BLANK_NODE_LABEL
          expect(tokens.first.value).to eq "_:foobar"
        end
      end

      it "tokenizes anonymous blank nodes" do
        ['[]', '[ ]'].each do |anon|
          tokenize(anon) do |tokens|
            expect(tokens.size).to eql 1
            expect(tokens.first.type).to eq :ANON
            expect(tokens.first.value).to eq anon
          end
        end
      end
    end

    describe "IRIREF" do
      it "tokenizes absolute IRI references" do
        tokenize(%q(<http://example.org/foobar>)) do |tokens|
          expect(tokens.size).to eql 1
          expect(tokens.first.type).to eq :IRIREF
          expect(tokens.first.value).to eq '<http://example.org/foobar>'
        end
      end

      it "tokenizes relative IRI references" do
        tokenize(%q(<foobar>)) do |tokens|
          expect(tokens.size).to eql 1
          expect(tokens.first.type).to eq :IRIREF
          expect(tokens.first.value).to eq '<foobar>'
        end
      end
    end

    describe "PNAME_NS" do
      it "tokenizes the empty prefix" do
        tokenize(%q(:)) do |tokens|
          expect(tokens.size).to eql 1
          expect(tokens.first.type).to eq :PNAME_NS
          expect(tokens.first.value).to eq ':'
        end
      end

      it "tokenizes labelled prefixes" do
        tokenize(%q(dc:)) do |tokens|
          expect(tokens.size).to eql 1
          expect(tokens.first.type).to eq :PNAME_NS
          expect(tokens.first.value).to eq "dc:"
        end
      end
    end

    describe "PNAME_LN" do
      it "tokenizes prefixed names" do
        tokenize(%q(dc:title)) do |tokens|
          expect(tokens.size).to eql 1
          expect(tokens.first.type).to eq :PNAME_LN
          expect(tokens.first.value).to eq "dc:title"
        end
      end

      it "prefixed names having an empty prefix label" do
        tokenize(%q(:title)) do |tokens|
          expect(tokens.size).to eql 1
          expect(tokens.first.type).to eq :PNAME_LN
          expect(tokens.first.value).to eq ":title"
        end
      end
    end

    describe "RDF literals" do
      it "tokenizes language-tagged literals" do
        tokenize(%q("Hello, world!"@en)) do |tokens|
          expect(tokens.size).to eql 2
          expect(tokens[0].type).to eq :STRING_LITERAL_QUOTE
          expect(tokens[0].value).to eq '"Hello, world!"'
          expect(tokens[1].type).to eq :LANGTAG
          expect(tokens[1].value).to eq "@en"
        end
        tokenize(%q("Hello, world!"@en-US)) do |tokens|
          expect(tokens.size).to eql 2
          expect(tokens[0].type).to eq :STRING_LITERAL_QUOTE
          expect(tokens[0].value).to eq '"Hello, world!"'
          expect(tokens[1].type).to eq :LANGTAG
          expect(tokens[1].value).to eq '@en-US'
        end
      end
      
      it "tokenizes multiple string literals" do
        tokenize(%q("1", "2")) do |tokens|
          expect(tokens.size).to eql 3
          expect(tokens[0].type).to eq :STRING_LITERAL_QUOTE
          expect(tokens[0].value).to eq '"1"'
          expect(tokens[1].type).to eq nil
          expect(tokens[1].value).to eq ','
          expect(tokens[2].type).to eq :STRING_LITERAL_QUOTE
          expect(tokens[2].value).to eq '"2"'
        end
      end

      it "datatyped literals" do
        tokenize(%q('3.1415'^^<http://www.w3.org/2001/XMLSchema#double>)) do |tokens|
          expect(tokens.size).to eql 3
          expect(tokens[0].type).to eq :STRING_LITERAL_SINGLE_QUOTE
          expect(tokens[0].value).to eq "'3.1415'"
          expect(tokens[1].type).to eq nil
          expect(tokens[1].value).to eq '^^'
          expect(tokens[2].type).to eq :IRIREF
          expect(tokens[2].value).to eq "<#{RDF::XSD.double}>"
        end

        tokenize(%q("3.1415"^^<http://www.w3.org/2001/XMLSchema#double>)) do |tokens|
          expect(tokens.size).to eql 3
          expect(tokens[0].type).to eq :STRING_LITERAL_QUOTE
          expect(tokens[0].value).to eq '"3.1415"'
          expect(tokens[1].type).to eq nil
          expect(tokens[1].value).to eq '^^'
          expect(tokens[2].type).to eq :IRIREF
          expect(tokens[2].value).to eq "<#{RDF::XSD.double}>"
        end
      end
    end

    describe "string terminals" do
      %w|^^ ( ) [ ] , ; . a true false @base @prefix|.each do |string|
        it "tokenizes the #{string.inspect} string" do
          tokenize(string) do |tokens|
            expect(tokens.size).to eql 1
            expect(tokens.first.type).to eq nil
            expect(tokens.first.value).to eq string
          end
        end
      end
    end

    describe "comments" do
      it "ignores the remainder of the current line" do
        tokenize("# :foo :bar", "# :foo :bar\n", "# :foo :bar\r\n") do |tokens|
          expect(tokens.size).to eql 0
        end
      end

      it "ignores leading whitespace" do
        tokenize(" # :foo :bar", "\n# :foo :bar", "\r\n# :foo :bar") do |tokens|
          expect(tokens.size).to eql 0
        end
      end

      it "resumes tokenization from the following line" do
        tokenize("# :foo\n:bar", "# :foo\r\n:bar") do |tokens|
          expect(tokens.size).to eql 1
          expect(tokens.first.type).to eq :PNAME_LN
          expect(tokens.first.value).to eq ":bar"
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
          lexer = EBNF::LL1::Lexer.tokenize(input, @terminals,
                                            unescape_terms:  @unescape_terms,
                                            whitespace:  RDF::Turtle::Terminals::WS)
          lexer.to_a # consumes the input
          expect(lexer.lineno).to eq lineno
        end
      end
    end

    describe "yielding tokens" do
      it "annotates tokens with the current line number" do
        results = %w(1 2 3 4)
        EBNF::LL1::Lexer.tokenize("1\n2\n3\n4", @terminals,
                                                unescape_terms:  @unescape_terms,
                                                whitespace:  RDF::Turtle::Terminals::WS
                                  ).each_token do |token|
          expect(token.type).to eq :INTEGER
          expect(token.value).to eq results.shift
        end
      end
    end

    describe "invalid input" do
      it "raises a lexer error" do
        expect { tokenize("SELECT foo WHERE {}") }.to raise_error EBNF::LL1::Lexer::Error
      end

      it "reports the invalid token which triggered the error" do
        begin
          tokenize("@prefix foo <>")
        rescue EBNF::LL1::Lexer::Error =>  error
          expect(error.token).to eq 'foo'
        end
        begin
          tokenize("@prefix foo: <>\n@prefix") {}
        rescue EBNF::LL1::Lexer::Error =>  error
          expect(error.token).to eq '@base'
        end
      end

      it "reports the line number where the error occurred" do
        begin
          tokenize("@prefix foo <>")
        rescue EBNF::LL1::Lexer::Error =>  error
          expect(error.lineno).to eq 1
        end
        begin
          tokenize("@prefix\nfoo <>")
        rescue EBNF::LL1::Lexer::Error =>  error
          expect(error.lineno).to eq 2
        end
      end
    end
    
    describe "reader tests" do
      {
        bbc:  %q(
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
            expect(tokens).not_to be_empty
          end
        end
      end
    end
  end

  def tokenize(*inputs, &block)
    options = inputs.last.is_a?(Hash) ? inputs.pop : {}
    inputs.each do |input|
      tokens = EBNF::LL1::Lexer.tokenize(input, @terminals,
                                         unescape_terms:  @unescape_terms,
                                         whitespace:  RDF::Turtle::Terminals::WS)
      expect(tokens).to be_a(EBNF::LL1::Lexer)
      block.call(tokens.to_a)
    end
  end
end
