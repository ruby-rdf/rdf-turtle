# coding: utf-8
$:.unshift "."
require 'spec_helper'
require 'ebnf'
require 'sxp'

describe EBNF do
  describe ".new" do
    {
      %{[2]     Prolog    ::=           BaseDecl? PrefixDecl*} =>
        %{((Prolog "2" rule (, (? BaseDecl) (* PrefixDecl))))},
      %{
        @terminals
        [3] terminal ::= [A-Z_]+
      } => %{((terminal "3" token (+ ([ "A-Z_"))))},
      %{
        [9] primary     ::= HEX
                        |   RANGE
                        |   ENUM 
                        |   O_RANGE
                        |   O_ENUM
                        |   STRING1
                        |   STRING2
                        |   '(' expression ')'
        
      } => %{((primary "9" rule (| HEX RANGE ENUM O_RANGE O_ENUM STRING1 STRING2 (, "(" expression ")"))))},
      %q{
        @pass           ::= (
                              [#x20#09#0d%0a]
                            | ('/*' ([^*] | '*' [^/])* '*/')
                            )+
        
      } => %q{((@pass "0" pass (+ (| ([ "#x20#09#0d%0a") (, "/*" (* (| ([ "^*") (, "*" ([ "^/")))) "*/")))))},
    }.each do |input, expected|
      it "parses #{input.inspect}" do
        parse(input).to_sxp.should produce(expected, @debug)
      end
    end
  end
  
  describe "#ruleParts" do
    {
      %{[2]     Prolog    ::=           BaseDecl? PrefixDecl*} =>
        %{(Prolog "2" #n (, (? BaseDecl) (* PrefixDecl)))},
    }.each do |input, expected|
      it "given #{input.inspect} produces #{expected}" do
        ebnf(:ruleParts, input).to_sxp.should produce(expected, @debug)
      end
    end
  end
  
  describe "#ebnf" do
    {
      "'abc' def" => %{((, "abc" def) "")},
      %{[0-9]} => %{(([ "0-9") "")},
      %{#00B7} => %{((# "#00B7") "")},
      %{[#x0300-#x036F]} => %{(([ "#x0300-#x036F") "")},
      %{[^<>'{}|^`]-[#x00-#x20]} => %{((- ([ "^<>'{}|^`") ([ "#x00-#x20")) "")},
      %{a b c} => %{((, a b c) "")},
      %{a? b c} => %{((, (? a) b c) "")},
      %(a - b) => %{((- a b) "")},
      %(a b c) => %{((, a b c) "")},
      %(a b? c) => %{((, a (? b) c) "")},
      %(a | b | c) => %{((| a b c) "")},
      %(a? b+ c*) => %{((, (? a) (+ b) (* c)) "")},
      %( | x xlist) => %{((| (, ()) (, x xlist)) "")},
      %(a | (b - c)) => %{((| a (- b c)) "")},
      %(a b | c d) => %{((| (, a b) (, c d)) "")},
      %(a | b | c) => %{((| a b c) "")},
      %{a) b c} => %{(a ") b c")},
      %(BaseDecl? PrefixDecl*) => %{((, (? BaseDecl) (* PrefixDecl)) "")},
      %(NCCHAR1 | '-' | [0-9] | #x00B7 | [#x0300-#x036F] | [#x203F-#x2040]) =>
        %{((| NCCHAR1 "-" ([ "0-9") (# "#x00B7") ([ "#x0300-#x036F") ([ "#x203F-#x2040")) "")}
    }.each do |input, expected|
      it "given #{input.inspect} produces #{expected}" do
        ebnf(:ebnf, input).to_sxp.should produce(expected, @debug)
      end
    end
  end
  
  describe "#diff" do
    {
      %{'abc' def}               => %{("abc" " def")},
      %{[0-9]}                   => %{(([ "0-9") "")},
      %{#00B7}                   => %{((# "#00B7") "")},
      %{[#x0300-#x036F]}         => %{(([ "#x0300-#x036F") "")},
      %{[^<>'{}|^`]-[#x00-#x20]} => %{((- ([ "^<>'{}|^`") ([ "#x00-#x20")) "")},
      %{a b c}                   => %{(a " b c")},
      %{a? b c}                  => %{((? a) " b c")},
      %(a - b)                   => %{((- a b) "")}
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
