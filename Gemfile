source "http://rubygems.org"

gemspec

gem 'rdf',  github: "ruby-rdf/rdf",  branch: "develop"
gem 'ebnf', github: "gkellogg/ebnf", branch: "develop"

group :development do
  gem "wirble"
  gem "byebug", platforms: :mri
  gem 'psych',  platforms: [:mri, :rbx]
end

group :development, :test do
  gem 'json-ld',        github: "ruby-rdf/json-ld",         branch: "develop"
  gem 'rdf-spec',       github: "ruby-rdf/rdf-spec",        branch: "develop"
  gem 'rdf-isomorphic', github: "ruby-rdf/rdf-isomorphic",  branch: "develop"
  gem 'rdf-vocab',      github: "ruby-rdf/rdf-vocab",       branch: "develop"
  gem 'sxp',            github: "gkellogg/sxp-ruby",        branch: "develop"
  gem "redcarpet",      platforms: :ruby
  gem 'simplecov',      require: false, platform: :mri
  gem 'coveralls',      require: false, platform: :mri
end

platforms :rbx do
  gem 'rubysl', '~> 2.0'
  gem 'rubinius', '~> 2.0'
  gem 'json'
end
