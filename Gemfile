source 'https://rubygems.org'
gemspec

# CI tooling (used by .github/workflows/ci.yml audit and lint jobs)
gem 'bundler-audit', '~> 0.9.3', require: false
gem 'rubocop', '~> 1.87', require: false
gem 'ruby_audit', '~> 3.1', require: false if Gem::Version.new(RUBY_VERSION) >= Gem::Version.new('3.1.0')
