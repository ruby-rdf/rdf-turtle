# coding: utf-8
RSpec::Matchers.define :match_re do |expected, info|
  match do |actual|
    actual.to_s.match(expected)
  end
  
  failure_message do |actual|
    "Match failed\n" +
    "#{info[:about]}\n" +
    "Input file:\n#{info[:input]}\n" +
    "Result:\n#{actual}\n" +
    "Expression: #{expected}\n" +
    "Debug:\n#{info[:trace]}"
  end  
end
