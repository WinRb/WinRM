require "bundler/gem_tasks"
require 'rspec/core/rake_task'

RSpec::Core::RakeTask.new(:spec) do |t|
  t.pattern = "spec/unit/**/*_spec.rb"
  t.rspec_opts = '--format documentation --color'
end

RSpec::Core::RakeTask.new(:spec_all) do |t|
  t.pattern = "spec/**/*_spec.rb"
  t.rspec_opts = '--format documentation --color'
end
