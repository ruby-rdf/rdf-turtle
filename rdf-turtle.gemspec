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

  gem.authors               = ['Gregg Kellogg']
  gem.email                 = 'public-rdf-ruby@w3.org'

  gem.platform              = Gem::Platform::RUBY
  gem.files                 = %w(AUTHORS README.md History UNLICENSE VERSION) + Dir.glob('lib/**/*.rb')
  gem.require_paths         = %w(lib)

  gem.required_ruby_version = '>= 2.4'
  gem.requirements          = []
  gem.add_runtime_dependency     'rdf',             '~> 3.1', '>= 3.1.2'
  gem.add_runtime_dependency     'ebnf',            '~> 2.0'
  gem.add_development_dependency 'erubis',          '~> 2.7'
  gem.add_development_dependency 'htmlentities',    '~> 4.3'
  gem.add_development_dependency 'rspec',           '~> 3.9'
  gem.add_development_dependency 'rspec-its',       '~> 1.3'
  gem.add_development_dependency 'rdf-isomorphic',  '~> 3.1'
  gem.add_development_dependency 'json-ld',         '~> 3.1'
  gem.add_development_dependency 'rdf-spec',        '~> 3.1'
  gem.add_development_dependency 'rdf-vocab',       '~> 3.1'

  gem.add_development_dependency 'rake',            '~> 13.0'
  gem.add_development_dependency 'yard' ,           '~> 0.9.20'
  gem.post_install_message  = nil
end
