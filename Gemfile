source "http://rubygems.org"

gemspec

gem 'rdf', git: "git://github.com/ruby-rdf/rdf.git", branch: "develop"
gem 'rdf-spec', git: "git://github.com/ruby-rdf/rdf-spec.git", branch: "develop"
gem 'rdf-isomorphic', git: "git://github.com/ruby-rdf/rdf-isomorphic.git", branch: "develop"
gem 'json-ld', git: "git://github.com/ruby-rdf/json-ld.git", branch: "develop"
gem 'ebnf', git: "git://github.com/gkellogg/ebnf.git", branch: "develop"

group :debug do
  gem "wirble"
  gem "debugger", platforms: :mri_19
  gem "byebug", platforms: :mri_20
end

platforms :rbx do
  gem 'rubysl', '~> 2.0'
  gem 'rubinius', '~> 2.0'
  gem 'json'
end
