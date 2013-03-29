#!/usr/bin/env ruby
$:.unshift(File.expand_path(File.join(File.dirname(__FILE__), 'lib')))
require 'rubygems'

namespace :gem do
  desc "Build the rdf-turtle-#{File.read('VERSION').chomp}.gem file"
  task :build => "lib/rdf/turtle/meta.rb" do
    sh "gem build rdf-turtle.gemspec && mv rdf-turtle-#{File.read('VERSION').chomp}.gem pkg/"
  end

  desc "Release the rdf-turtle-#{File.read('VERSION').chomp}.gem file"
  task :release do
    sh "gem push pkg/rdf-turtle-#{File.read('VERSION').chomp}.gem"
  end
end

desc 'Default: run specs.'
task :default => :spec
task :specs => :spec

require 'rspec/core/rake_task'
desc 'Run specifications'
RSpec::Core::RakeTask.new do |spec|
  spec.rspec_opts = %w(--options spec/spec.opts) if File.exists?('spec/spec.opts')
end

desc "Run specs through RCov"
RSpec::Core::RakeTask.new("spec:rcov") do |spec|
  spec.rcov = true
  spec.rcov_opts =  %q[--exclude "spec"]
end

desc "Generate HTML report specs"
RSpec::Core::RakeTask.new("doc:spec") do |spec|
  spec.rspec_opts = ["--format", "html", "-o", "doc/spec.html"]
end

require 'yard'
namespace :doc do
  YARD::Rake::YardocTask.new
end

desc 'Create versions of ebnf files in etc'
task :etc => %w{etc/turtle.sxp etc/turtle.ll1.sxp}

desc 'Build first, follow and branch tables'
task :meta => "lib/rdf/turtle/meta.rb"

file "lib/rdf/turtle/meta.rb" => "etc/turtle.bnf" do |t|
  sh %{
    ebnf --ll1 turtleDoc --format rb \
      --mod-name RDF::Turtle::Meta \
      --output lib/rdf/turtle/meta.rb \
      etc/turtle.bnf
  }
end

file "etc/turtle.ll1.sxp" => "etc/turtle.bnf" do |t|
  sh %{
    ebnf --ll1 turtleDoc --format sxp \
      --output etc/turtle.ll1.sxp \
      etc/turtle.bnf
  }
end

file "etc/turtle.sxp" => "etc/turtle.bnf" do |t|
  sh %{
    ebnf --bnf --format sxp \
      --output etc/turtle.sxp \
      etc/turtle.bnf
  }
end
