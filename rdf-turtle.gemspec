#!/usr/bin/env ruby -rubygems
# -*- encoding: utf-8 -*-

Gem::Specification.new do |gem|
  gem.version               = File.read('VERSION').chomp
  gem.date                  = File.mtime('VERSION').strftime('%Y-%m-%d')

  gem.name                  = "rdf-turtle"
  gem.homepage              = "https://github.com/ruby-rdf/rdf-turtle"
  gem.license               = 'Unlicense'
  gem.summary               = "Turtle reader/writer for Ruby."
  gem.description           = %q{RDF::Turtle is an Turtle reader/writer for the RDF.rb library suite.}
  gem.metadata           = {
    "documentation_uri" => "https://ruby-rdf.github.io/rdf-turtle",
    "bug_tracker_uri"   => "https://github.com/ruby-rdf/rdf-turtle/issues",
    "homepage_uri"      => "https://github.com/ruby-rdf/rdf-turtle",
    "mailing_list_uri"  => "https://lists.w3.org/Archives/Public/public-rdf-ruby/",
    "source_code_uri"   => "https://github.com/ruby-rdf/rdf-turtle",
  }

  gem.authors               = ['Gregg Kellogg']
  gem.email                 = 'public-rdf-ruby@w3.org'

  gem.platform              = Gem::Platform::RUBY
  gem.files                 = %w(AUTHORS README.md History UNLICENSE VERSION) + Dir.glob('lib/**/*.rb')
  gem.require_paths         = %w(lib)

  gem.required_ruby_version = '>= 3.0'
  gem.requirements          = []
  gem.add_runtime_dependency     'rdf',             '~> 3.3'
  gem.add_runtime_dependency     'ebnf',            '~> 2.5'
  gem.add_runtime_dependency     'base64',          '~> 0.2'
  gem.add_runtime_dependency     'bigdecimal',      '~> 3.1', '>= 3.1.5'
  gem.add_development_dependency 'erubis',          '~> 2.7'
  gem.add_development_dependency 'getoptlong',      '~> 0.2'
  gem.add_development_dependency 'htmlentities',    '~> 4.3'
  gem.add_development_dependency 'rspec',           '~> 3.12'
  gem.add_development_dependency 'rspec-its',       '~> 1.3'
  gem.add_development_dependency 'rdf-isomorphic',  '~> 3.3'
  gem.add_development_dependency 'json-ld',         '~> 3.3'
  gem.add_development_dependency 'rdf-spec',        '~> 3.3'
  gem.add_development_dependency 'rdf-vocab',       '~> 3.3'
  gem.post_install_message  = nil
end
