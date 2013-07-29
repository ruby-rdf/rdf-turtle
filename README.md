# RDF::Turtle reader/writer

[Turtle][] reader/writer for [RDF.rb][RDF.rb] .

[![Gem Version](https://badge.fury.io/rb/rdf-turtle.png)](http://badge.fury.io/rb/rdf-turtle)
[![Build Status](https://travis-ci.org/ruby-rdf/rdf-turtle.png?branch=master)](http://travis-ci.org/ruby-rdf/rdf-turtle)

## Description
This is a [Ruby][] implementation of a [Turtle][] parser for [RDF.rb][].

## Features
RDF::Turtle parses [Turtle][Turtle] and [N-Triples][N-Triples] into statements or triples. It also serializes to Turtle.

Install with `gem install rdf-turtle`

* 100% free and unencumbered [public domain](http://unlicense.org/) software.
* Implements a complete parser for [Turtle][].
* Compatible with Ruby 1.8.7+, Ruby >= 1.9, and JRuby 1.7+.
* Optional streaming writer, to serialize large graphs

## Usage
Instantiate a reader from a local file:

    graph = RDF::Graph.load("etc/doap.ttl", :format => :ttl)

Define `@base` and `@prefix` definitions, and use for serialization using `:base_uri` an `:prefixes` options.

Canonicalize and validate using `:canonicalize` and `:validate` options.

Write a graph to a file:

    RDF::Turtle::Writer.open("etc/test.ttl") do |writer|
       writer << graph
    end

## Documentation
Full documentation available on [Rubydoc.info][Turtle doc]

### Principle Classes
* {RDF::Turtle::Format}
  * {RDF::Turtle::TTL}
    Asserts :ttl format, text/turtle mime-type and .ttl file extension.
* {RDF::Turtle::Reader}
* {RDF::Turtle::Writer}

### Variations from the spec
In some cases, the specification is unclear on certain issues:

* The LC version of the [Turtle][] specification separates rules for `@base` and `@prefix` with
  closing '.' from the
  SPARQL-like `BASE` and `PREFIX` without closing '.'. This version implements a more flexible
  syntax where the `@` and closing `.` are optional and `base/prefix` are matched case independently.
* Additionally, both `a` and `A` match `rdf:type`.

### Freebase-specific Reader
There is a special reader useful for processing [Freebase Dumps][]. To invoke
this, add the `:freebase => true` option to the {RDF::Turtle::Reader.new}, or
use {RDF::Turtle::FreebaseReader} directly. As with {RDF::Turtle::Reader},
prefix definitions may be passed in using the `:prefixes` option to
RDF::Turtle::FreebaseReader} using the standard mechanism defined
for `RDF::Reader`.

The [Freebase Dumps][] have a very normalized form, similar to N-Triples but
with prefixes. They also have a large amount of garbage. This Reader is
optimized for this format and will perform faster error recovery.

An example of reading Freebase dumps:

    require "rdf/turtle"
    fb = "../freebase/freebase-rdf-2013-03-03-00-00.ttl"
    fb_prefixes = {
      :ns => "http://rdf.freebase.com/ns/",
      :key => "http://rdf.freebase.com/key/",
      :owl => "http://www.w3.org/2002/07/owl#>",
      :rdfs => "http://www.w3.org/2000/01/rdf-schema#",
      :rdf => "http://www.w3.org/1999/02/22-rdf-syntax-ns#",
      :xsd => "http://www.w3.org/2001/XMLSchema#"
    }
    RDF::Turtle::Reader.open(fb,
      :freebase => true,
      :prefixes => fb_prefixes) do |r|

      r.each_statement {|stmt| puts stmt.to_ntriples}
    end
## Implementation Notes
The reader uses the [EBNF][] gem to generate first, follow and branch tables, and uses
the `Parser` and `Lexer` modules to implement the Turtle parser.

The parser takes branch and follow tables generated from the original [Turtle
EBNF Grammar][Turtle EBNF] described in the [specification][Turtle]. Branch and
Follow tables are specified in {RDF::Turtle::Meta}, which is in turn generated
using the [EBNF][] gem.

## Dependencies

* [Ruby](http://ruby-lang.org/) (>= 1.8.7) or (>= 1.8.1 with [Backports][])
* [RDF.rb](http://rubygems.org/gems/rdf) (>= 1.0)
* [EBNF][] (>= 0.1.0)

## Installation

The recommended installation method is via [RubyGems](http://rubygems.org/).
To install the latest official release of the `RDF::Turtle` gem, do:

    % [sudo] gem install rdf-turtle

## Mailing List
* <http://lists.w3.org/Archives/Public/public-rdf-ruby/>

## Author
* [Gregg Kellogg](http://github.com/gkellogg) - <http://greggkellogg.net/>

## Contributing
* Do your best to adhere to the existing coding conventions and idioms.
* Don't use hard tabs, and don't leave trailing whitespace on any line.
* Do document every method you add using [YARD][] annotations. Read the
  [tutorial][YARD-GS] or just look at the existing code for examples.
* Don't touch the `.gemspec`, `VERSION` or `AUTHORS` files. If you need to
  change them, do so on your private branch only.
* Do feel free to add yourself to the `CREDITS` file and the corresponding
  list in the the `README`. Alphabetical order applies.
* Do note that in order for us to merge any non-trivial changes (as a rule
  of thumb, additions larger than about 15 lines of code), we need an
  explicit [public domain dedication][PDD] on record from you.

## License
This is free and unencumbered public domain software. For more information,
see <http://unlicense.org/> or the accompanying {file:UNLICENSE} file.

[Ruby]:         http://ruby-lang.org/
[RDF]:          http://www.w3.org/RDF/
[YARD]:         http://yardoc.org/
[YARD-GS]:      http://rubydoc.info/docs/yard/file/docs/GettingStarted.md
[PDD]:          http://lists.w3.org/Archives/Public/public-rdf-ruby/2010May/0013.html
[RDF.rb]:       http://rubydoc.info/github/ruby-rdf/rdf/master/frames
[EBNF]:         http://rubygems.org/gems/ebnf
[Backports]:    http://rubygems.org/gems/backports
[N-Triples]:    http://www.w3.org/TR/rdf-testcases/#ntriples
[Turtle]:       http://www.w3.org/TR/2012/WD-turtle-20120710/
[Turtle doc]:   http://rubydoc.info/github/ruby-rdf/rdf-turtle/master/file/README.md
[Turtle EBNF]:  http://dvcs.w3.org/hg/rdf/file/default/rdf-turtle/turtle.bnf
[Freebase Dumps]: https://developers.google.com/freebase/data