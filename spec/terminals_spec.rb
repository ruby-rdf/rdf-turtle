require File.join(File.dirname(__FILE__), 'spec_helper')

describe RDF::Turtle::Terminals do
  describe "when matching Unicode input" do
    strings = [
      ["\xC3\x80",         "\xC3\x96"],         # \u00C0-\u00D6
      ["\xC3\x98",         "\xC3\xB6"],         # \u00D8-\u00F6
      ["\xC3\xB8",         "\xCB\xBF"],         # \u00F8-\u02FF
      ["\xCD\xB0",         "\xCD\xBD"],         # \u0370-\u037D
      ["\xCD\xBF",         "\xE1\xBF\xBF"],     # \u037F-\u1FFF
      ["\xE2\x80\x8C",     "\xE2\x80\x8D"],     # \u200C-\u200D
      ["\xE2\x81\xB0",     "\xE2\x86\x8F"],     # \u2070-\u218F
      ["\xE2\xB0\x80",     "\xE2\xBF\xAF"],     # \u2C00-\u2FEF
      ["\xE3\x80\x81",     "\xED\x9F\xBF"],     # \u3001-\uD7FF
      ["\xEF\xA4\x80",     "\xEF\xB7\x8F"],     # \uF900-\uFDCF
      ["\xEF\xB7\xB0",     "\xEF\xBF\xBD"],     # \uFDF0-\uFFFD
      ["\xF0\x90\x80\x80", "\xF3\xAF\xBF\xBF"], # \u{10000}-\u{EFFFF}]
    ]
    it "matches the PN_CHARS_BASE production correctly" do
      strings.each do |range|
        range.each do |string|
          string.force_encoding(Encoding::UTF_8) if string.respond_to?(:force_encoding) # Ruby 1.9+
          string.should match(RDF::Turtle::Terminals::PN_CHARS_BASE)
        end
      end
    end

    it "matches the IRI_REF production correctly" do
      strings.each do |range|
        range.each do |string|
          string = "<#{string}>"
          string.force_encoding(Encoding::UTF_8) if string.respond_to?(:force_encoding) # Ruby 1.9+
          string.should match(RDF::Turtle::Terminals::IRI_REF)
        end
      end
    end
    
    %w(
      ! # $ % & ' ( ) * + , - . / 0 1 2 3 4 5 6 7 8 9 : / < = ? @
      A B C D E F G H I J K L M N O P Q R S T U V W X Y Z
      _ a b c d e f g h i j k l m n o p q r s t u v w x y z ~
      ab\\u00E9xy ab\xC3\xA9xy>
      \\u03B1:a \xCE\xB1:a
      a\\u003Ab a\x3Ab
      \\U00010000 \xF0\x90\x80\x80
      \\U000EFFFF \xF3\xAF\xBF\xBF
    ).each do |string|
      it "matches <scheme:#{string.inspect}>" do
        begin
          string = "<scheme:#{string}>"
          string.force_encoding(Encoding::UTF_8) if string.respond_to?(:force_encoding) # Ruby 1.9+
          string.should match(RDF::Turtle::Terminals::IRI_REF)
        rescue RSpec::Expectations::ExpectationNotMetError
          pending "Escapes in IRIs"
        end
      end
    end
  end
end
