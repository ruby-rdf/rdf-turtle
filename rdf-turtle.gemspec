#!/usr/bin/env ruby -rubygems
# -*- encoding: utf-8 -*-

Gem::Specification.new do |gem|
  gem.version               = File.read('VERSION').chomp
  gem.date                  = File.mtime('VERSION').strftime('%Y-%m-%d')

  gem.name                  = "rdf-turtle"
  gem.homepage              = "http://ruby-rdf.github.com/rdf-turtle"
  gem.license               = 'Public Domain' if gem.respond_to?(:license=)
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

  gem.required_ruby_version = '>= 1.9.2'
  gem.requirements          = []
  gem.add_runtime_dependency     'rdf',             '>= 1.1'
  gem.add_runtime_dependency     'ebnf',            '>= 0.3.3'
  gem.add_development_dependency 'open-uri-cached', '>= 0.0.5'
  gem.add_development_dependency 'rspec',           '>= 2.12.0'
  gem.add_development_dependency 'rdf-isomorphic',  '>= 1.1'
  gem.add_development_dependency 'json-ld',         '>= 1.1'
  gem.add_development_dependency 'yard' ,           '>= 0.8.3'
  gem.add_development_dependency 'rdf-spec',        '>= 1.1'

  # Rubinius has it's own dependencies
  if RUBY_ENGINE == "rbx" && RUBY_VERSION >= "2.1.0"
    gem.add_development_dependency "rubysl-open-uri"
    gem.add_development_dependency "rubysl-prettyprint"
  end

  gem.add_development_dependency 'rake'
  gem.post_install_message  = nil
end