# coding: utf-8
require 'rdf/isomorphic'
require 'json'
JSON_STATE = JSON::State.new(
   indent:        "  ",
   space:         " ",
   space_before:  "",
   object_nl:     "\n",
   array_nl:      "\n"
 )

def normalize(graph)
  case graph
  when RDF::Queryable then graph
  when IO, StringIO
    RDF::Graph.new.load(graph, base_uri:  @info.about, validate: false)
  else
    # Figure out which parser to use
    g = RDF::Repository.new
    reader_class = detect_format(graph)
    reader_class.new(graph, base_uri:  @info.about, validate: false).each {|s| g << s}
    g
  end
end

Info = Struct.new(:about, :coment, :debug, :input, :result, :action, :expected, :errors)

RSpec::Matchers.define :be_equivalent_graph do |expected, info|
  match do |actual|
    @info = if info.respond_to?(:input)
      info
    elsif info.is_a?(Hash)
      identifier = info[:identifier] || expected.is_a?(RDF::Graph) ? expected.context : info[:about]
      debug = info[:debug]
      if debug.is_a?(Array)
        debug = debug.map {|s| s.dup.force_encoding(Encoding::UTF_8)}.join("\n")
      end
      Info.new(about: identifier, comment: (info[:comment] || ""), debug: debug, errors: info[:errors])
    else
      Info.new(about: expected.is_a?(RDF::Enumerable) ? expected.context : info, debug: info.to_s)
    end
    @expected = normalize(expected)
    @actual = normalize(actual)
    @actual.isomorphic_with?(@expected) rescue false
  end

  failure_message do |actual|
    info = @info.respond_to?(:comment) ? @info.comment : @info.inspect
    if @expected.is_a?(RDF::Graph) && @actual.size != @expected.size
      "Graph entry count differs:\nexpected: #{@expected.size}\nactual:   #{@actual.size}"
    elsif @expected.is_a?(Array) && @actual.size != @expected.length
      "Graph entry count differs:\nexpected: #{@expected.length}\nactual:   #{@actual.size}"
    else
      "Graph differs"
    end +
    "\n#{info + "\n" unless info.empty?}" +
    (@info.action ? "Input file: #{@info.action}\n" : "") +
    (@info.result ? "Result file: #{@info.result}\n" : "") +
    "Unsorted Expected:\n#{@expected.dump(:ntriples, standard_prefixes:  true, validate: false)}" +
    "Unsorted Results:\n#{@actual.dump(:ntriples, standard_prefixes:  true, validate: false)}" +
    (@info.errors && !@info.errors.empty? ? "\nErrors:\n#{@info.errors.join("\n")}\n" : "") +
    (@info.debug ? "\nDebug:\n#{@info.debug}" : "")
  end  
end

RSpec::Matchers.define :match_re do |expected, info|
  match do |actual|
    @info = if info.respond_to?(:input)
      info
    else
      Info.new(expected.is_a?(RDF::Graph) ? expected.context : info, "", info.to_s)
    end
    @expected = expected
    @actual = actual
    @actual.to_s.match(@expected)
  end
  
  failure_message do |actual|
    info = @info.respond_to?(:comment) ? @info.comment : @info.inspect
    "Match failed" +
    "\n#{info + "\n" unless info.empty?}" +
    (@info.action ? "Input file: #{@info.action}\n" : "") +
    (@info.result ? "Output file: #{@info.result}\n" : "") +
    "Expression: #{@expected}\n" +
    "Unsorted Results:\n#{@actual}" +
    (@info.debug ? "\nDebug:\n#{@info.debug}" : "")
  end  
end

RSpec::Matchers.define :produce do |expected, info|
  match do |actual|
    @info = if info.respond_to?(:input)
      info
    else
      Info.new(about: info, comment: "", debug: info.to_s)
    end
    expect(actual).to eq expected
  end
  
  failure_message do |actual|
    "Expected: #{[Array, Hash].include?(expected.class) ? expected.to_json(JSON_STATE) : expected.inspect}\n" +
    "Actual  : #{[Array, Hash].include?(actual.class) ? actual.to_json(JSON_STATE) : actual.inspect}\n" +
    (@info.errors && !@info.errors.empty? ? "\nErrors:\n#{@info.errors.join("\n")}\n" : "") +
    "Processing results:\n#{@info.debug.join("\n")}"
  end
end
