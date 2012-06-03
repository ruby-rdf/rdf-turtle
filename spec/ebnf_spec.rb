# coding: utf-8
$:.unshift "."
require 'spec_helper'
require 'ebnf'
require 'sxp'

describe EBNF do
  describe ".new" do
    {
      %{[2]     Prolog    ::=           BaseDecl? PrefixDecl*} =>
        %{((Prolog "2" rule (seq (opt BaseDecl) (star PrefixDecl))))},
      %{
        @terminals
        [3] terminal ::= [A-Z_]+
      } => %{((terminal "3" token (plus (range "A-Z_"))))},
      %{
        [9] primary     ::= HEX
                        |   RANGE
                        |   ENUM 
                        |   O_RANGE
                        |   O_ENUM
                        |   STRING1
                        |   STRING2
                        |   '(' expression ')'
        
      } => %{((primary "9" rule (alt HEX RANGE ENUM O_RANGE O_ENUM STRING1 STRING2 (seq "(" expression ")"))))},
      %q{
        @pass           ::= (
                              [#x20#09#0d%0a]
                            | ('/*' ([^*] | '*' [^/])* '*/')
                            )+
        
      } => %q{((@pass "0" pass (plus (alt (range "#x20#09#0d%0a") (seq "/*" (star (alt (range "^*") (seq "*" (range "^/")))) "*/")))))},
    }.each do |input, expected|
      it "parses #{input.inspect}" do
        parse(input).ast.to_sxp.should produce(expected, @debug)
      end
    end
  end
  
  describe "#ruleParts" do
    {
      %{[2]     Prolog    ::=           BaseDecl? PrefixDecl*} =>
        %{(Prolog "2" #n (seq (opt BaseDecl) (star PrefixDecl)))},
    }.each do |input, expected|
      it "given #{input.inspect} produces #{expected}" do
        ebnf(:ruleParts, input).to_sxp.should produce(expected, @debug)
      end
    end
  end
  
  describe "#ebnf" do
    {
      "'abc' def" => %{((seq "abc" def) "")},
      %{[0-9]} => %{((range "0-9") "")},
      %{#00B7} => %{((hex "#00B7") "")},
      %{[#x0300-#x036F]} => %{((range "#x0300-#x036F") "")},
      %{[^<>'{}|^`]-[#x00-#x20]} => %{((diff (range "^<>'{}|^`") (range "#x00-#x20")) "")},
      %{a b c} => %{((seq a b c) "")},
      %{a? b c} => %{((seq (opt a) b c) "")},
      %(a - b) => %{((diff a b) "")},
      %(a b c) => %{((seq a b c) "")},
      %(a b? c) => %{((seq a (opt b) c) "")},
      %(a | b | c) => %{((alt a b c) "")},
      %(a? b+ c*) => %{((seq (opt a) (plus b) (star c)) "")},
      %( | x xlist) => %{((alt (seq ()) (seq x xlist)) "")},
      %(a | (b - c)) => %{((alt a (diff b c)) "")},
      %(a b | c d) => %{((alt (seq a b) (seq c d)) "")},
      %(a | b | c) => %{((alt a b c) "")},
      %{a) b c} => %{(a ") b c")},
      %(BaseDecl? PrefixDecl*) => %{((seq (opt BaseDecl) (star PrefixDecl)) "")},
      %(NCCHAR1 | '-' | [0-9] | #x00B7 | [#x0300-#x036F] | [#x203F-#x2040]) =>
        %{((alt NCCHAR1 "-" (range "0-9") (hex "#x00B7") (range "#x0300-#x036F") (range "#x203F-#x2040")) "")}
    }.each do |input, expected|
      it "given #{input.inspect} produces #{expected}" do
        ebnf(:ebnf, input).to_sxp.should produce(expected, @debug)
      end
    end
  end
  
  describe "#diff" do
    {
      %{'abc' def}               => %{("abc" " def")},
      %{[0-9]}                   => %{((range "0-9") "")},
      %{#00B7}                   => %{((hex "#00B7") "")},
      %{[#x0300-#x036F]}         => %{((range "#x0300-#x036F") "")},
      %{[^<>'{}|^`]-[#x00-#x20]} => %{((diff (range "^<>'{}|^`") (range "#x00-#x20")) "")},
      %{a b c}                   => %{(a " b c")},
      %{a? b c}                  => %{((opt a) " b c")},
      %(a - b)                   => %{((diff a b) "")}
    }.each do |input, expected|
      it "given #{input.inspect} produces #{expected}" do
        ebnf(:diff, input).to_sxp.should produce(expected, @debug)
      end
    end
  end
  
  def ebnf(method, value, options = {})
    @debug = []
    options = {:debug => @debug}.merge(options)
    EBNF.new("", options).send(method, value)
  end
  
  def parse(value, options = {})
    @debug = []
    options = {:debug => @debug}.merge(options)
    EBNF.new(value, options)
  end
end
