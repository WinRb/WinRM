# encoding: UTF-8
require 'rubygems'
require 'bundler/setup'
require 'rspec/core/rake_task'
require 'rubocop/rake_task'
require 'bundler/gem_tasks'

# Change to the directory of this file.
Dir.chdir(File.expand_path('../', __FILE__))

desc 'Open a Pry console for this library'
task :console do
  require 'pry'
  require 'winrm'
  ARGV.clear
  Pry.start
end

RSpec::Core::RakeTask.new(:spec) do |task|
  task.pattern = 'tests/spec/**/*_spec.rb'
  task.rspec_opts = ['--color', '-f documentation', '-r ./tests/spec/spec_helper']
end

# Run the integration test suite
RSpec::Core::RakeTask.new(:integration) do |task|
  task.pattern = 'tests/integration/*_spec.rb'
  task.rspec_opts = ['--color', '-f documentation', '-r ./tests/integration/spec_helper']
end

RuboCop::RakeTask.new

task default: [:spec, :rubocop]

task all: [:default, :integration]
