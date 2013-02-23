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
      } => %{((terminal "3" terminal (plus (range "A-Z_"))))},
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

  describe "#make_bnf" do
    {
      %{[2]     Prolog    ::=           BaseDecl? PrefixDecl*} =>
      [%{(Prolog "2" rule (seq _Prolog_1 _Prolog_2))},
       %{(_Prolog_1 "2.1" rule (alt g:empty BaseDecl))},
       %{(_Prolog_2 "2.2" rule (alt g:empty __Prolog_2_star))},
       %{(__Prolog_2_star "2.2*" rule (seq PrefixDecl _Prolog_2))}],
      %{
        [9] primary     ::= HEX
                        |   RANGE
                        |   ENUM 
                        |   O_RANGE
                        |   O_ENUM
                        |   STRING1
                        |   STRING2
                        |   '(' expression ')'
        
      } =>
      [%{(primary "9" rule (alt HEX RANGE ENUM O_RANGE O_ENUM STRING1 STRING2 _primary_1))},
       %{(_primary_1 "9.1" rule (seq __primary_1_term1 expression __primary_1_term2))},
       %{(__primary_1_term1 "9.1.term1" terminal "(")},
       %{(__primary_1_term2 "9.1.term2" terminal ")")}],
    }.each do |input, expected|
      it "parses #{input.inspect}" do
        parse(input).make_bnf.ast.map(&:to_s).should produce(expected, @debug)
      end
    end
  end

  describe "#ruleParts" do
    {
      %{[2]     Prolog    ::=           BaseDecl? PrefixDecl*} =>
        %{(Prolog "2" rule (seq (opt BaseDecl) (star PrefixDecl)))},
      %{[2] declaration ::= '@terminals' | '@pass'} =>
        %{(declaration "2" rule (alt "@terminals" "@pass"))},
      %{[9] postfix     ::= primary ( [?*+] )?} =>
        %{(postfix "9" rule (seq primary (opt (range "?*+"))))},
      %{[18] STRING2    ::= "'" (CHAR - "'")* "'"} =>
        %{(STRING2 "18" terminal (seq "'" (star (diff CHAR "'")) "'"))},
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
      %{a) b c} => %{(a " b c")},
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
      %{( [?*+] )?}              => %{((opt (range "?*+")) "")},
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

describe EBNF::Rule do
  let(:debug) {[]}
  let(:ebnf) {EBNF.new("", :debug => debug)}
  subject {EBNF::Rule.new("rule", "0", [], :ebnf => ebnf)}

  describe "#ttl_expr" do
    {
      "ebnf[1]" => [
        [:star, [:alt, :declaration, :rule]],
        %{g:star [ g:alt ( :declaration :rule ) ] .}
      ],
      "ebnf[2]" => [
        [:alt, "@terminals", "@pass"],
        %{g:alt ( "@terminals" "@pass" ) .}
      ],
      "ebnf[5]" => [
        :alt,
        %{g:seq ( :alt ) .}
      ],
      "ebnf[9]" => [
        [:seq, :primary, [:opt, [:range, "?*+"]]],
        %{g:seq ( :primary [ g:opt [ re:matches "[?*+]" ] ] ) .}
      ],
      "IRIREF" => [
        [:seq, "<", [:star, [:alt, [:range, "^#x00-#x20<>\"{}|^`\\"], :UCHAR]], ">"],
        %{g:seq ( "<" [ g:star [ g:alt ( [ re:matches "[^\\\\u0000-\\\\u0020<>\\\"{}|^`\\\\]" ] :UCHAR ) ] ] ">" ) .}
      ]
    }.each do |title, (expr, expected)|
      it title do
        res = subject.send(:ttl_expr, expr, "g", 0, false)
        res.each {|r| r.should be_a(String)}
          
        res.
          join("\n").
          gsub(/\s+/, ' ').
          should produce(expected, debug)
      end
    end
  end
  
  describe "#cclass" do
    {
      "passes normal stuff" => [
        %{^<>'{}|^`},
        %{[^<>'{}|^`]}
      ],
      "turns regular hex range into unicode range" => [
        %{#x0300-#x036F},
        %{[\\u0300-\\u036F]}
      ],
      "turns short hex range into unicode range" => [
        %{#xC0-#xD6},
        %{[\\u00C0-\\u00D6]}
      ],
      "turns 3 char hex range into unicode range" => [
        %{#x370-#x37D},
        %{[\\u0370-\\u037D]}
      ],
      "turns long hex range into unicode range" => [
        %{#x000300-#x00036F},
        %{[\\U00000300-\\U0000036F]}
      ],
      "turns 5 char hex range into unicode range" => [
        %{#x00370-#x0037D},
        %{[\\U00000370-\\U0000037D]}
      ],
    }.each do |title, (input, expected)|
      it title do
        subject.send(:cclass, input).should produce(expected, debug)
      end
    end
  end

  describe "#to_bnf" do
    {
      "no-rewrite" => [
        [:seq],
        [EBNF::Rule.new(:rule, "0", [:seq])]
      ],
      "embedded rule" => [
        [:seq, [:alt]],
        [EBNF::Rule.new(:rule, "0", [:seq, :_rule_1]),
         EBNF::Rule.new(:_rule_1, "0.1", [:alt])]
      ],
      "opt rule" => [
        [:opt, :foo],
        [EBNF::Rule.new(:rule, "0", [:alt, :"g:empty", :foo])]
      ],
      "two opt rule" => [
        [:alt, [:opt, :foo], [:opt, :bar]],
        [EBNF::Rule.new(:rule, "0", [:alt, :_rule_1, :_rule_2]),
         EBNF::Rule.new(:_rule_1, "0.1", [:alt, :"g:empty", :foo]),
         EBNF::Rule.new(:_rule_2, "0.2", [:alt, :"g:empty", :bar])]
      ],
      "star rule" => [
        [:star, :foo],
        [EBNF::Rule.new(:rule, "0", [:alt, :"g:empty", :_rule_star]),
         EBNF::Rule.new(:_rule_star, "0.1", [:seq, :foo, :rule])]
      ],
      "plus rule" => [
        [:plus, :foo],
        [EBNF::Rule.new(:rule, "0", [:seq, :foo, :_rule_1]),
         EBNF::Rule.new(:_rule_1, "0.1", [:alt, :"g:empty", :__rule_1_star]),
         EBNF::Rule.new(:__rule_1_star, "0.1*", [:seq, :foo, :_rule_1])]
      ],
      "string rule" => [
        [:seq, "foo", "bar"],
        [EBNF::Rule.new(:rule, "0", [:seq, :_rule_term1, :_rule_term2]),
         EBNF::Rule.new(:_rule_term1, "0.term1", "foo", :kind => :terminal),
         EBNF::Rule.new(:_rule_term2, "0.term2", "bar", :kind => :terminal)]
      ],
      "ebnf[1]" => [
        [:star, [:alt, :declaration, :rule]],
        [EBNF::Rule.new(:rule, "0", [:alt, :"g:empty", :_rule_star]),
         EBNF::Rule.new(:_rule_star, "0*", [:seq, :_rule_1, :rule]),
         EBNF::Rule.new(:_rule_1, "0.1", [:alt, :declaration, :rule])]
      ],
      "ebnf[9]" => [
        [:seq, :primary, [:opt, [:range, "?*+"]]],
        [EBNF::Rule.new(:rule, "0", [:seq, :primary, :_rule_1]),
         EBNF::Rule.new(:_rule_1, "0.1", [:alt, :"g:empty", [:range, "?*+"]])]
      ],
      "IRIREF" => [
        [:seq, "<", [:star, [:alt, [:range, "^#x00-#x20<>\"{}|^`\\"], :UCHAR]], ">"],
        [EBNF::Rule.new(:rule, "0", [:seq, :_rule_term1, :_rule_1, :_rule_term2]),
         EBNF::Rule.new(:_rule_term1, "0.term1", "<", :kind => :terminal),
         EBNF::Rule.new(:_rule_term2, "0.term2", ">", :kind => :terminal),
         EBNF::Rule.new(:_rule_1, "0.1", [:alt, :"g:empty", :__rule_1_star]),
         EBNF::Rule.new(:__rule_1_star, "0.1*", [:seq, :__rule_1_1, :_rule_1]),
         EBNF::Rule.new(:__rule_1_1, "0.1.1", [:alt, [:range, "^#x00-#x20<>\"{}|^`\\"], :UCHAR])]
       ]
    }.each do |title, (expr, expected)|
      it title do
        EBNF::Rule.new(:rule, "0", expr).to_bnf.should == expected
      end
    end

    describe "#rewrite" do
      it "updates rule references" do
        subject.expr = [:do, :re, [:me, :fa, :do], :do]
        rsrc = EBNF::Rule.new(:do, "0", [])
        rdst = EBNF::Rule.new(:DO, "0", [])
        subject.rewrite(rsrc, rdst).expr.should == [:DO, :re, [:me, :fa, :do], :DO]
      end
    end
  end
end