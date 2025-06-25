# encoding: utf-8
require 'ebnf/ll1/lexer'

module RDF::Turtle
  module Terminals
    # Definitions of token regular expressions used for lexical analysis
    ##
    # Unicode regular expressions for Ruby 1.9+ with the Oniguruma engine.
    U_CHARS1         = Regexp.compile(<<-EOS.gsub(/\s+/, ''))
                         [\\u00C0-\\u00D6]|[\\u00D8-\\u00F6]|[\\u00F8-\\u02FF]|
                         [\\u0370-\\u037D]|[\\u037F-\\u1FFF]|[\\u200C-\\u200D]|
                         [\\u2070-\\u218F]|[\\u2C00-\\u2FEF]|[\\u3001-\\uD7FF]|
                         [\\uF900-\\uFDCF]|[\\uFDF0-\\uFFFD]|[\\u{10000}-\\u{EFFFF}]
                       EOS
    U_CHARS2         = Regexp.compile("\\u00B7|[\\u0300-\\u036F]|[\\u203F-\\u2040]", Regexp::FIXEDENCODING).freeze
    IRI_RANGE        = Regexp.compile("[[^<>\"{}|^`\\\\]&&[^\\x00-\\x20]]", Regexp::FIXEDENCODING).freeze

    UCHAR                = EBNF::LL1::Lexer::UCHAR
    PERCENT              = /%[0-9A-Fa-f]{2}/u.freeze
    PN_LOCAL_ESC         = /\\[_~\.\-\!$\&'\(\)\*\+,;=\/\?\#@%]/u.freeze
    PLX                  = /#{PERCENT}|#{PN_LOCAL_ESC}/u.freeze
    PN_CHARS_BASE        = /[A-Z]|[a-z]|#{U_CHARS1}/u.freeze
    PN_CHARS_U           = /_|#{PN_CHARS_BASE}/u.freeze
    PN_CHARS             = /-|\d|#{PN_CHARS_U}|#{U_CHARS2}/u.freeze
    PN_LOCAL_BODY        = /(?:(?:\.|:|#{PN_CHARS}|#{PLX})*(?:#{PN_CHARS}|:|#{PLX}))?/u.freeze
    PN_CHARS_BODY        = /(?:(?:\.|#{PN_CHARS})*#{PN_CHARS})?/u.freeze
    PN_PREFIX            = /#{PN_CHARS_BASE}#{PN_CHARS_BODY}/u.freeze
    PN_LOCAL             = /(?:\d|:|#{PN_CHARS_U}|#{PLX})#{PN_LOCAL_BODY}/u.freeze
    EXPONENT             = /[eE][+-]?\d+/u.freeze
    ECHAR                = /\\[tbnrf\\"']/u.freeze
    IRIREF               = /<(?:#{IRI_RANGE}|#{UCHAR})*>/u.freeze
    PNAME_NS             = /#{PN_PREFIX}?:/u.freeze
    PNAME_LN             = /#{PNAME_NS}#{PN_LOCAL}/u.freeze
    BLANK_NODE_LABEL     = /_:(?:\d|#{PN_CHARS_U})(?:(?:#{PN_CHARS}|\.)*#{PN_CHARS})?/u.freeze
    LANG_DIR              = /@([a-zA-Z]+(?:-[a-zA-Z0-9]+)*(?:--[a-zA-Z]+)?)/u.freeze
    INTEGER              = /[+-]?\d+/u.freeze
    DECIMAL              = /[+-]?(?:\d*\.\d+)/u.freeze
    DOUBLE               = /[+-]?(?:\d+\.\d*#{EXPONENT}|\.\d+#{EXPONENT}|\d+#{EXPONENT})/u.freeze
    STRING_LITERAL_SINGLE_QUOTE      = /'(?:[^\'\\\n\r]|#{ECHAR}|#{UCHAR})*'/u.freeze
    STRING_LITERAL_QUOTE             = /"(?:[^\"\\\n\r]|#{ECHAR}|#{UCHAR})*"/u.freeze
    STRING_LITERAL_LONG_SINGLE_QUOTE = /'''(?:(?:'|'')?(?:[^'\\]|#{ECHAR}|#{UCHAR}))*'''/um.freeze
    STRING_LITERAL_LONG_QUOTE        = /"""(?:(?:"|"")?(?:[^"\\]|#{ECHAR}|#{UCHAR}))*"""/um.freeze

    WS                   = /(?:\s|(?:#[^\n\r]*))+/um.freeze
    ANON                 = /\[#{WS}*\]/um.freeze
    PREFIX               = /@?prefix/ui.freeze
    BASE                 = /@?base/ui.freeze
    RDF_VERSION          = /@?version/ui.freeze
  
  end
end