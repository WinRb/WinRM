require "bundler/gem_tasks"
require 'rspec/core/rake_task'

RSpec::Core::RakeTask.new(:spec) do |t|
  t.pattern = "test/spec/*_spec.rb"
  t.rspec_opts = '--format documentation --color'
end