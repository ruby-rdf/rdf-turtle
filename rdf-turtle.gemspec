#!/usr/bin/env ruby -rubygems
# -*- encoding: utf-8 -*-

Gem::Specification.new do |gem|
  gem.version               = File.read('VERSION').chomp
  gem.date                  = File.mtime('VERSION').strftime('%Y-%m-%d')

  gem.name                  = "rdf-turtle"
  gem.homepage              = "http://ruby-rdf.github.com/rdf-turtle"
  gem.license               = 'Unlicense'
  gem.summary               = "Turtle reader/writer for Ruby."
  gem.description           = %q{RDF::Turtle is an Turtle reader/writer for the RDF.rb library suite.}
  gem.rubyforge_project     = 'rdf-turtle'

  gem.authors               = ['Gregg Kellogg']
  gem.email                 = 'public-rdf-ruby@w3.org'

  gem.platform              = Gem::Platform::RUBY
  gem.files                 = %w(AUTHORS README.md History UNLICENSE VERSION) + Dir.glob('lib/**/*.rb')
  #gem.bindir               = %q(bin)
  #gem.default_executable   = gem.executables.first
  gem.require_paths         = %w(lib)
  gem.extensions            = %w()
  gem.test_files            = %w()
  gem.has_rdoc              = false

  gem.required_ruby_version = '>= 2.2.2'
  gem.requirements          = []
  gem.add_runtime_dependency     'rdf',             '~> 2.0'
  gem.add_runtime_dependency     'ebnf',            '~> 1.0', '>= 1.0.1'
  gem.add_development_dependency 'rspec',           '~> 3.0'
  gem.add_development_dependency 'rspec-its',       '~> 1.0'
  gem.add_development_dependency 'rdf-isomorphic',  '~> 2.0'
  gem.add_development_dependency 'json-ld',         '~> 2.0'
  gem.add_development_dependency 'rdf-spec',        '~> 2.0'
  gem.add_development_dependency 'rdf-vocab',       '~> 2.0'

  gem.add_development_dependency 'rake',            '~> 10.4'
  gem.add_development_dependency 'yard' ,           '~> 0.8'
  gem.post_install_message  = nil
end