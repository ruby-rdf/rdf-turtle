source "http://rubygems.org"

gemspec

gem 'ebnf', git: "git://github.com/gkellogg/ebnf.git", branch: "develop"

group :development do
  gem "wirble"
  gem "byebug", platforms: :mri_21
  gem 'psych',      platforms: [:mri, :rbx]
end

group :development, :test do
  gem "redcarpet", platforms: :ruby
  gem 'simplecov',  require: false
  gem 'coveralls',  require: false
end

platforms :rbx do
  gem 'rubysl', '~> 2.0'
  gem 'rubinius', '~> 2.0'
  gem 'json'
end
