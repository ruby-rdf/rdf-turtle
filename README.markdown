# RDF::Turtle reader/writer
[Turtle][] reader/writer for [RDF.rb][RDF.rb] .

## Description
This is a [Ruby][] implementation of a [Turtle][] parser for
[RDF.rb][].

## Features
RDF::Turtle parses [Turtle][Turtle] and [N-Triples][N-Triples] into statements or triples. It also serializes to Turtle.

Install with `gem install rdf-turtle`

* 100% free and unencumbered [public domain](http://unlicense.org/) software.
* Implements a complete parser for [Turtle][].
* Compatible with Ruby 1.8.7+, Ruby 1.9.x, and JRuby 1.4/1.5.

## Usage
Instantiate a reader from a local file:

    RDF::Turtle::Reader.open("etc/foaf.ttl") do |reader|
       reader.each_statement do |statement|
         puts statement.inspect
       end
    end
    
or

    graph = RDF::Graph.load("etc/foaf.ttl", :format => :ttl)
    

Define `@base` and `@prefix` definitions, and use for serialization using `:base_uri` an `:prefixes` options

Write a graph to a file:

    RDF::Turtle::Writer.open("etc/test.ttl") do |writer|
       writer << graph
    end

## Documentation
Full documentation available on [RubyForge](http://rdf.rubyforge.org/turtle)

### Principle Classes
* {RDF::Turtle::Format}
  * {RDF::Turtle::TTL}
    Asserts :ttl format, text/turtle mime-type and .ttl file extension.
* {RDF::Turtle::Reader}
* {RDF::Turtle::Writer}

## Implementation Notes
The parser is driven through a rules table contained in lib/rdf/n3/reader/meta.rb. This includes
branch rules to indicate productions to be taken based on a current production. Terminals are denoted
through a set of regular expressions used to match each type of terminal.

The [meta.rb][file:lib/rdf/turtle/reader/meta.rb] file is generated from etc/turtle.bnf
(taken from http://www.w3.org/2000/10/swap/grammar/turtle.bnf) to generate a Turtle/N3 representation of the grammar, transform
this to and LL1 representation and use this to create meta.rb.

[etc/turtle.bnf][file:etc/turtle.bnf] is itself used to generate meta.rb using script/build_meta.

Using SWAP utilities, this is done as follows:

    python http://www.w3.org/2000/10/swap/grammar/ebnf2turtle.py \
      etc/turtle.bnf \
      ttl language \
      'http://www.w3.org/2000/10/swap/grammar/turtle#' > etc/turtle.n3
      
    python http://www.w3.org/2000/10/swap/cwm.py etc/turtle.n3 \
      http://www.w3.org/2000/10/swap/grammar/ebnf2bnf.n3 \
      http://www.w3.org/2000/10/swap/grammar/first_follow.n3 \
      --think --data > etc/turtle-bnf.n3
      
## Dependencies

* [Ruby](http://ruby-lang.org/) (>= 1.8.7) or (>= 1.8.1 with [Backports][])
* [RDF.rb](http://rubygems.org/gems/rdf) (>= 0.3.0)

## Installation

The recommended installation method is via [RubyGems](http://rubygems.org/).
To install the latest official release of the `SPARQL::Grammar` gem, do:

    % [sudo] gem install rdf-turtle

## Mailing List
* <http://lists.w3.org/Archives/Public/public-rdf-ruby/>

## Author
* [Gregg Kellogg](http://github.com/gkellogg) - <http://kellogg-assoc.com/>

## Contributing
------------
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

[Ruby]:       http://ruby-lang.org/
[RDF]:        http://www.w3.org/RDF/
[YARD]:       http://yardoc.org/
[YARD-GS]:    http://rubydoc.info/docs/yard/file/docs/GettingStarted.md
[PDD]:        http://lists.w3.org/Archives/Public/public-rdf-ruby/2010May/0013.html
[RDF.rb]:     http://rdf.rubyforge.org/
[YARD]:       http://yardoc.org/
[YARD-GS]:    http://rubydoc.info/docs/yard/file/docs/GettingStarted.md
[PDD]:        http://unlicense.org/#unlicensing-contributions
[Backports]:  http://rubygems.org/gems/backports
[Turtle]:     http://www.w3.org/TR/2011/WD-turtle-20110809/