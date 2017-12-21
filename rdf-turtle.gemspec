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
  #gem.add_runtime_dependency     'rdf',             '~> 3.0'
  gem.add_runtime_dependency     'rdf',             '>= 2.2', '< 4.0'
  gem.add_runtime_dependency     'ebnf',            '~> 1.1'
  gem.add_development_dependency 'rspec',           '~> 3.7'
  gem.add_development_dependency 'rspec-its',       '~> 1.2'
  #gem.add_development_dependency 'rdf-isomorphic',  '~> 3.0'
  #gem.add_development_dependency 'json-ld',         '~> 3.0'
  #gem.add_development_dependency 'rdf-spec',        '~> 3.0'
  #gem.add_development_dependency 'rdf-vocab',       '~> 3.0'
  gem.add_development_dependency 'rdf-isomorphic',  '>= 2.0', '< 4.0'
  gem.add_development_dependency 'json-ld',         '>= 2.1', '< 4.0'
  gem.add_development_dependency 'rdf-spec',        '>= 2.2', '< 4.0'
  gem.add_development_dependency 'rdf-vocab',       '>= 2.2', '< 4.0'

  gem.add_development_dependency 'rake',            '~> 12.0'
  gem.add_development_dependency 'yard' ,           '~> 0.9.12'
  gem.post_install_message  = nil
end
