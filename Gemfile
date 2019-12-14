source "https://rubygems.org"

gemspec

gem 'rdf',  git: "https://github.com/ruby-rdf/rdf",  branch: "develop"
gem 'ebnf', git: "https://github.com/dryruby/ebnf",  branch: "develop"

group :development do
  gem "byebug", platforms: :mri
  gem 'psych',  platforms: [:mri, :rbx]
end

group :development, :test do
  gem 'json-ld',        git: "https://github.com/ruby-rdf/json-ld",         branch: "develop"
  gem 'rdf-spec',       git: "https://github.com/ruby-rdf/rdf-spec",        branch: "develop"
  gem 'rdf-isomorphic', git: "https://github.com/ruby-rdf/rdf-isomorphic",  branch: "develop"
  gem 'rdf-vocab',      git: "https://github.com/ruby-rdf/rdf-vocab",       branch: "develop"
  gem 'sxp',            git: "https://github.com/dryruby/sxp.rb",           branch: "develop"
  gem "redcarpet",      platforms: :ruby
  gem 'simplecov',      platforms: :mri
  gem 'coveralls',      '~> 0.8', platforms: :mri
end
