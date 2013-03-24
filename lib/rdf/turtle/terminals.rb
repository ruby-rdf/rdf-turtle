require 'ebnf/ll1/lexer'

module RDF::Turtle
  module Terminals
    # Definitions of token regular expressions used for lexical analysis
  
    if RUBY_VERSION >= '1.9'
      ##
      # Unicode regular expressions for Ruby 1.9+ with the Oniguruma engine.
      U_CHARS1         = Regexp.compile(<<-EOS.gsub(/\s+/, ''))
                           [\\u00C0-\\u00D6]|[\\u00D8-\\u00F6]|[\\u00F8-\\u02FF]|
                           [\\u0370-\\u037D]|[\\u037F-\\u1FFF]|[\\u200C-\\u200D]|
                           [\\u2070-\\u218F]|[\\u2C00-\\u2FEF]|[\\u3001-\\uD7FF]|
                           [\\uF900-\\uFDCF]|[\\uFDF0-\\uFFFD]|[\\u{10000}-\\u{EFFFF}]
                         EOS
      U_CHARS2         = Regexp.compile("\\u00B7|[\\u0300-\\u036F]|[\\u203F-\\u2040]").freeze
      IRI_RANGE        = Regexp.compile("[[^<>\"{}|^`\\\\]&&[^\\x00-\\x20]]").freeze
    else
      ##
      # UTF-8 regular expressions for Ruby 1.8.x.
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
      IRI_RANGE        = Regexp.compile(<<-EOS.gsub(/\s+/, ''))
                           \\x21|                                             (?# ")
                           [\\x23-\\x3b]|\\x3d|                               (?# < & >)
                           [\\x3f-\\x5b]|\\x5d|\\x5f|                         (?# \ ^ `)
                           [\\x61-\\x7a]|                                     (?# { } |)
                           [\\x7e-\\xff]
                         EOS
    end

    # 26
    UCHAR                = EBNF::LL1::Lexer::UCHAR
    # 170s
    PERCENT              = /%[0-9A-Fa-f]{2}/.freeze
    # 172s
    PN_LOCAL_ESC         = /\\[_~\.\-\!$\&'\(\)\*\+,;=:\/\?\#@%]/.freeze
    # 169s
    PLX                  = /#{PERCENT}|#{PN_LOCAL_ESC}/.freeze.freeze
    # 163s
    PN_CHARS_BASE        = /[A-Z]|[a-z]|#{U_CHARS1}/.freeze
    # 164s
    PN_CHARS_U           = /_|#{PN_CHARS_BASE}/.freeze
    # 166s
    PN_CHARS             = /-|[0-9]|#{PN_CHARS_U}|#{U_CHARS2}/.freeze
    PN_LOCAL_BODY        = /(?:(?:\.|:|#{PN_CHARS}|#{PLX})*(?:#{PN_CHARS}|:|#{PLX}))?/.freeze
    PN_CHARS_BODY        = /(?:(?:\.|#{PN_CHARS})*#{PN_CHARS})?/.freeze
    # 167s
    PN_PREFIX            = /#{PN_CHARS_BASE}#{PN_CHARS_BODY}/.freeze
    # 168s
    PN_LOCAL             = /(?:[0-9]|:|#{PN_CHARS_U}|#{PLX})#{PN_LOCAL_BODY}/.freeze
    # 154s
    EXPONENT             = /[eE][+-]?[0-9]+/
    # 159s
    ECHAR                = /\\[tbnrf\\"']/
    # 18
    IRIREF               = /<(?:#{IRI_RANGE}|#{UCHAR})*>/.freeze
    # 139s
    PNAME_NS             = /#{PN_PREFIX}?:/.freeze
    # 140s
    PNAME_LN             = /#{PNAME_NS}#{PN_LOCAL}/.freeze
    # 141s
    BLANK_NODE_LABEL     = /_:(?:[0-9]|#{PN_CHARS_U})(?:(?:#{PN_CHARS}|\.)*#{PN_CHARS})?/.freeze
    # 144s
    LANGTAG              = /@[a-zA-Z]+(?:-[a-zA-Z0-9]+)*/.freeze
    # 19
    INTEGER              = /[+-]?[0-9]+/.freeze
    # 20
    DECIMAL              = /[+-]?(?:[0-9]*\.[0-9]+)/.freeze
    # 21
    DOUBLE               = /[+-]?(?:[0-9]+\.[0-9]*#{EXPONENT}|\.?[0-9]+#{EXPONENT})/.freeze
    # 22
    STRING_LITERAL_QUOTE      = /'(?:[^\'\\\n\r]|#{ECHAR}|#{UCHAR})*'/.freeze
    # 23
    STRING_LITERAL_SINGLE_QUOTE      = /"(?:[^\"\\\n\r]|#{ECHAR}|#{UCHAR})*"/.freeze.freeze
    # 24
    STRING_LITERAL_LONG_SINGLE_QUOTE = /'''(?:(?:'|'')?(?:[^'\\]|#{ECHAR}|#{UCHAR}))*'''/m.freeze
    # 25
    STRING_LITERAL_LONG_QUOTE = /"""(?:(?:"|"")?(?:[^"\\]|#{ECHAR}|#{UCHAR}))*"""/m.freeze

    # 161s
    WS                   = / |\t|\r|\n  /.freeze
    # 162s
    ANON                 = /\[#{WS}*\]/m.freeze
    # 28t
    SPARQL_PREFIX        = /prefix/i.freeze
    # 29t
    SPARQL_BASE          = /base/i.freeze
  
  end
end