# encoding: UTF-8
require 'rubygems'
require 'bundler/setup'
require 'rspec/core/rake_task'
require 'rubocop/rake_task'
require 'bundler/gem_tasks'

# Change to the directory of this file.
Dir.chdir(File.expand_path('../', __FILE__))

RSpec::Core::RakeTask.new(:spec) do |task|
  task.pattern = 'spec/*_spec.rb'
  task.rspec_opts = ['--color', '-f documentation']
  task.rspec_opts << '-tunit'
end

# Run the integration test suite
RSpec::Core::RakeTask.new(:integration) do |task|
  task.pattern = 'spec/*_spec.rb'
  task.rspec_opts = ['--color', '-f documentation']
  task.rspec_opts << '-tintegration'
end

RuboCop::RakeTask.new

task default: [:spec, :rubocop]

task all: [:default, :integration]
