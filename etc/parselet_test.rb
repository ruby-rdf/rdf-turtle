require 'parslet'

class Mini < Parslet::Parser
  ##
  # Unicode regular expressions for Ruby 1.9+ with the Oniguruma engine.
  module Unicode
    if RUBY_VERSION >= '1.9'
      U_CHARS1         = Regexp.compile(<<-EOS.gsub(/\s+/, ''))
                           [\\u00C0-\\u00D6]|[\\u00D8-\\u00F6]|[\\u00F8-\\u02FF]|
                           [\\u0370-\\u037D]|[\\u037F-\\u1FFF]|[\\u200C-\\u200D]|
                           [\\u2070-\\u218F]|[\\u2C00-\\u2FEF]|[\\u3001-\\uD7FF]|
                           [\\uF900-\\uFDCF]|[\\uFDF0-\\uFFFD]|[\\u{10000}-\\u{EFFFF}]
                         EOS
      U_CHARS2         = Regexp.compile("\\u00B7|[\\u0300-\\u036F]|[\\u203F-\\u2040]")
    end
  end

  ##
  # UTF-8 regular expressions for Ruby 1.8.x.
  module UTF_8
    if RUBY_VERSION < '1.9'
      U_CHARS1         = Regexp.compile(<<-EOS.gsub(/\s+/, ''))
                           \\xC3[\\x80-\\x96]|                                (?# [\\u00C0-\\u00D6]|)
                           \\xC3[\\x98-\\xB6]|                                (?# [\\u00D8-\\u00F6]|)
                           \\xC3[\\xB8-\\xBF]|[\\xC4-\\xCB][\\x80-\\xBF]|     (?# [\\u00F8-\\u02FF]|)
                           \\xCD[\\xB0-\\xBD]|                                (?# [\\u0370-\\u037D]|)
                           \\xCD\\xBF|[\\xCE-\\xDF][\\x80-\\xBF]|             (?# [\\u037F-\\u1FFF]|)
                           \\xE0[\\xA0-\\xBF][\\x80-\\xBF]|                   (?# ...)
                           \\xE1[\\x80-\\xBF][\\x80-\\xBF]|                   (?# ...)
                           \\xE2\\x80[\\x8C-\\x8D]|                           (?# [\\u200C-\\u200D]|)
                           \\xE2\\x81[\\xB0-\\xBF]|                           (?# [\\u2070-\\u218F]|)
                           \\xE2[\\x82-\\x85][\\x80-\\xBF]|                   (?# ...)
                           \\xE2\\x86[\\x80-\\x8F]|                           (?# ...)
                           \\xE2[\\xB0-\\xBE][\\x80-\\xBF]|                   (?# [\\u2C00-\\u2FEF]|)
                           \\xE2\\xBF[\\x80-\\xAF]|                           (?# ...)
                           \\xE3\\x80[\\x81-\\xBF]|                           (?# [\\u3001-\\uD7FF]|)
                           \\xE3[\\x81-\\xBF][\\x80-\\xBF]|                   (?# ...)
                           [\\xE4-\\xEC][\\x80-\\xBF][\\x80-\\xBF]|           (?# ...)
                           \\xED[\\x80-\\x9F][\\x80-\\xBF]|                   (?# ...)
                           \\xEF[\\xA4-\\xB6][\\x80-\\xBF]|                   (?# [\\uF900-\\uFDCF]|)
                           \\xEF\\xB7[\\x80-\\x8F]|                           (?# ...)
                           \\xEF\\xB7[\\xB0-\\xBF]|                           (?# [\\uFDF0-\\uFFFD]|)
                           \\xEF[\\xB8-\\xBE][\\x80-\\xBF]|                   (?# ...)
                           \\xEF\\xBF[\\x80-\\xBD]|                           (?# ...)
                           \\xF0[\\x90-\\xBF][\\x80-\\xBF][\\x80-\\xBF]|      (?# [\\u{10000}-\\u{EFFFF}])
                           [\\xF1-\\xF2][\\x80-\\xBF][\\x80-\\xBF][\\x80-\\xBF]|
                           \\xF3[\\x80-\\xAF][\\x80-\\xBF][\\x80-\\xBF]       (?# ...)
                         EOS
      U_CHARS2         = Regexp.compile(<<-EOS.gsub(/\s+/, ''))
                           \\xC2\\xB7|                                        (?# \\u00B7|)
                           \\xCC[\\x80-\\xBF]|\\xCD[\\x80-\\xAF]|             (?# [\\u0300-\\u036F]|)
                           \\xE2\\x80\\xBF|\\xE2\\x81\\x80                    (?# [\\u203F-\\u2040])
                         EOS
    end
  end

  include RUBY_VERSION >= '1.9' ? Unicode : UTF_8
  # Whitespace
  rule(:newline)              { match('[\r\n]') }
  rule(:line_comment)         { str('#') >> (newline.absent? >> any).repeat }
  rule(:spaces)               { line_comment | match('[ \t\r\n]') }
  rule(:spaces?)              { spaces.maybe }
  rule(:dot)                  { str('.') }
  
  root(:spaces?)
end

def parse(str)
  mini = Mini.new
  print "Parsing #{str}: "
  
  p mini.parse(str)
rescue Parslet::ParseFailed => error
  puts error, mini.root.error_tree
end

parse "# T"
