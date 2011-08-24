# coding: utf-8
require File.join(File.dirname(__FILE__), '..', 'spec_helper')
require 'rdf/ll1/scanner'

describe RDF::LL1::Scanner do
  describe ".open" do
    it "initializes with an #read" do
      thing = File.open(__FILE__)
      thing.should_receive(:read).and_return("line1\n", "", "", "")
      thing.should_receive(:gets).at_least(1).times.and_return("")
      thing.should_receive(:eof?).at_least(1).times.and_return(false)
      scanner = RDF::LL1::Scanner.open(thing)
      scanner.rest.should == "line1\n"
      scanner.scan(/.*/).should == "line1"
      scanner.scan(/\s*/m).should == "\n"
    end

    it "initializes with a StringIO" do
      scanner = RDF::LL1::Scanner.open(StringIO.new("line1\nline2\n"))
      scanner.rest.should == "line1\nline2\n"
      scanner.eos?.should be_false
    end

    it "initializes with a filename" do
      File.should_receive(:open).with("foo").and_return(StringIO.new("foo"))
      scanner = RDF::LL1::Scanner.open("foo")
    end
    
    it "passes input data to block" do
      block_called = false
      scanner = RDF::LL1::Scanner.open(StringIO.new("foo")) do |string|
        block_called = true
        "bar"
      end
      scanner.rest.should == "bar"
      block_called.should be_true
    end
  end
  
  describe "#eos?" do
    it "returns true if at both eos and eof" do
      scanner = RDF::LL1::Scanner.open(StringIO.new(""))
      scanner.eos?.should be_true
    end
  end
  
  describe "#rest" do
    it "returns remaining scanner contents if not at eos" do
      scanner = RDF::LL1::Scanner.open(StringIO.new("foo\n"))
      scanner.rest.should == "foo\n"
    end
    
    it "returns next line from file if at eos" do
      scanner = RDF::LL1::Scanner.open(StringIO.new("\nfoo\n"))
      scanner.rest.should == "\nfoo\n"
      scanner.scan(/\s*/m)
      scanner.rest.should == "foo\n"
    end
    
    it "returns \"\" if at eos and eof" do
      scanner = RDF::LL1::Scanner.open(StringIO.new(""))
      scanner.rest.should == ""
    end
  end
  
  describe "#scan" do
    context "simple terminals" do
      it "returns a word" do
        scanner = RDF::LL1::Scanner.open(StringIO.new("foo bar"))
        scanner.scan(/\w+/).should == "foo"
      end
      
      it "returns a STRING_LITERAL1" do
        scanner = RDF::LL1::Scanner.open(StringIO.new("'string' foo"))
        scanner.scan(/'((?:[^\x27\x5C\x0A\x0D])*)'/).should == "'string'"
      end
      
      it "returns a STRING_LITERAL_LONG1" do
        scanner = RDF::LL1::Scanner.open(StringIO.new("'''\nstring\nstring''' foo"), :ml_start => /'''|"""/)
        scanner.scan(/'''((?:(?:'|'')?(?:[^'\\])+)*)'''/m).should == "'''\nstring\nstring'''"
      end
      
      it "scans a multi-line string" do
         string = %q('''
          <html:a="b"/>
          '''
        )
        scanner = RDF::LL1::Scanner.open(StringIO.new(string), :ml_start => /'''|"""/)
        scanner.scan(/'''((?:(?:'|'')?(?:[^'\\])+)*)'''/m).should_not be_empty
      end
      
      it "scans a longer multi-line string" do
         string = %q('''
          <html:b xmlns:html="http://www.w3.org/1999/xhtml" html:a="b"/>
          '''
        )
        scanner = RDF::LL1::Scanner.open(StringIO.new(string), :ml_start => /'''|"""/)
        scanner.scan(/'''((?:(?:'|'')?(?:[^'\\])+)*)'''/m).should_not be_empty
      end
    end
  end
end