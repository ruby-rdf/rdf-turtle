#!/usr/bin/env ruby
require 'rubygems'

namespace :gem do
  desc "Build the rdf-turtle-#{File.read('VERSION').chomp}.gem file"
  task :build do
    sh "gem build rdf-turtle.gemspec && mv rdf-turtle-#{File.read('VERSION').chomp}.gem pkg/"
  end

  desc "Release the rdf-turtle-#{File.read('VERSION').chomp}.gem file"
  task :release do
    sh "gem push pkg/rdf-turtle-#{File.read('VERSION').chomp}.gem"
  end
end
