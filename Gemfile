source "http://rubygems.org"

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

  # Until version >= 3.4.2 with support for Ruby 2.6
  gem "webmock",        git: "https://github.com/bblimke/webmock"
  gem 'simplecov',      require: false, platform: :mri
  gem 'coveralls',      require: false, platform: :mri
end

platforms :rbx do
  gem 'rubysl', '~> 2.0'
  gem 'rubinius', '~> 2.0'
  gem 'json'
end
