# encoding: UTF-8
require 'date'

version = File.read(File.expand_path('../VERSION', __FILE__)).strip

Gem::Specification.new do |s|
  s.platform = Gem::Platform::RUBY
  s.name = 'winrm'
  s.version = version
  s.date = Date.today.to_s

  s.author = ['Dan Wanek', 'Paul Morton']
  s.email = ['dan.wanek@gmail.com', 'paul@themortonsonline.com']
  s.homepage = 'https://github.com/WinRb/WinRM'

  s.summary = 'Ruby library for Windows Remote Management'
  s.description = <<-EOF
    Ruby library for Windows Remote Management
  EOF
  s.license = 'Apache-2.0'

  s.files = `git ls-files`.split(/\n/)
  s.require_path = 'lib'
  s.rdoc_options = %w(-x test/ -x examples/)
  s.extra_rdoc_files = %w(README.md LICENSE)

  s.bindir = 'bin'
  s.executables = ['rwinrm']
  s.required_ruby_version = '>= 1.9.0'
  s.add_runtime_dependency 'gssapi', '~> 1.2'
  s.add_runtime_dependency 'httpclient', '~> 2.2', '>= 2.2.0.2'
  s.add_runtime_dependency 'rubyntlm', '~> 0.4.0'
  s.add_runtime_dependency 'uuidtools', '~> 2.1.2'
  s.add_runtime_dependency 'logging', '~> 1.6', '>= 1.6.1'
  s.add_runtime_dependency 'nori', '~> 2.0'
  s.add_runtime_dependency 'gyoku', '~> 1.0'
  s.add_runtime_dependency 'builder', '>= 2.1.2'
  s.add_development_dependency 'rspec', '~> 3.2'
  s.add_development_dependency 'rake', '~> 10.3'
  s.add_development_dependency 'rubocop', '~> 0.28'
end
