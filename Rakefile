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


TTL_DIR = File.expand_path(File.dirname(__FILE__))

# Use SWAP tools expected to be in ../swap
# Download from http://www.w3.org/2000/10/swap/
file "lib/rdf/turtle/meta.rb" => ["etc/turtle-ll1.n3", "script/gramLL1"] do |t|
  sh %{
    script/gramLL1 \
      --grammar etc/turtle-ll1.n3 \
      --lang 'http://www.w3.org/2000/10/swap/grammar/turtle#language' \
      --output lib/rdf/turtle/meta.rb
  }
end

file "etc/turtle-ll1.n3" => "etc/turtle.n3" do
  sh %{
  ( cd ../swap/grammar;
    PYTHONPATH=../.. python ../cwm.py #{TTL_DIR}/etc/turtle.n3 \
      ebnf2bnf.n3 \
      first_follow.n3 \
      --think --data
  )  > etc/turtle-ll1.n3
  }
end

file "etc/turtle-bnf.n3" => "etc/turtle.n3" do
  sh %{
  ( cd ../swap/grammar;
    PYTHONPATH=../.. python ../cwm.py #{TTL_DIR}/etc/turtle.n3 \
      ebnf2bnf.n3 \
      --think --data
  ) > etc/turtle-bnf.n3
  }
end

file "etc/turtle.n3" => "etc/turtle.bnf" do
  # Don't run this, as bnf generation didn't create correct Turtle for @base and @prefix
  sh %{
  ( cd ../swap/grammar;
    PYTHONPATH=../.. python ebnf2turtle.py #{TTL_DIR}/etc/turtle.bnf \
      ttl language 'http://www.w3.org/2000/10/swap/grammar/turtle#'
  ) | sed -e 's/^  ".*"$/  g:seq (&)/'  > etc/turtle.n3
  }
end
