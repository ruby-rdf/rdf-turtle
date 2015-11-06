source "http://rubygems.org"

gemspec

gem 'rdf', git: "git://github.com/ruby-rdf/rdf.git", branch: "develop"
gem 'ebnf', git: "git://github.com/gkellogg/ebnf.git", branch: "develop"

group :development do
  gem "wirble"
  gem "byebug", platforms: :mri_21
  gem 'psych',      platforms: [:mri, :rbx]
end

group :development, :test do
  gem "redcarpet", platforms: :ruby
  gem 'rdf-spec', git: "git://github.com/ruby-rdf/rdf-spec.git", branch: "develop"
  gem 'rdf-isomorphic', git: "git://github.com/ruby-rdf/rdf-isomorphic.git", branch: "develop"
  gem 'rdf-vocab', git: "git://github.com/ruby-rdf/rdf-vocab.git", branch: "develop"
  gem 'json-ld', git: "git://github.com/ruby-rdf/json-ld.git", branch: "develop"
  gem 'simplecov',  require: false
  gem 'coveralls',  require: false
end

platforms :rbx do
  gem 'rubysl', '~> 2.0'
  gem 'rubinius', '~> 2.0'
  gem 'json'
end
