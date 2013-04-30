# -*- encoding: utf-8 -*-
require 'date'

lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'winrm/version'

Gem::Specification.new do |spec|
  spec.platform = Gem::Platform::RUBY
  spec.name = 'winrm'
  spec.version = WinRM::VERSION
  spec.date		= Date.today.to_s

  spec.authors = ['Dan Wanek','Paul Morton']
  spec.email = ['dan.wanek@gmail.com','']
  spec.homepage = "http://github.com/zenchild/WinRM"

  spec.summary = 'Ruby library for Windows Remote Management'
  spec.description	= <<-EOF
    Ruby library for Windows Remote Management
  EOF

  spec.files =`git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.required_ruby_version	= '>= 1.9.0'
  spec.add_runtime_dependency  'nokogiri', '~> 1.5.0'
  spec.add_runtime_dependency  'httpclient'
  spec.add_runtime_dependency 'nori'
  spec.add_runtime_dependency 'gyoku'
  spec.add_runtime_dependency  'rubyntlm'
  spec.add_runtime_dependency  'uuidtools', '~> 2.1.2'
end
