# -*- encoding: utf-8 -*-
require 'date'

version = File.read(File.expand_path("../VERSION", __FILE__)).strip

Gem::Specification.new do |s|
  s.platform = Gem::Platform::RUBY
  s.name = 'winrm'
  s.version = version
  s.date		= Date.today.to_s

  s.author = 'Dan Wanek'
  s.email = 'dan.wanek@gmail.com'
  s.homepage = "http://github.com/zenchild/WinRM"

  s.summary = 'Ruby library for Windows Remote Management'
  s.description	= <<-EOF
    Ruby library for Windows Remote Management
  EOF

  s.files = `git ls-files`.split(/\n/)
  s.require_path = "lib"
  s.rdoc_options	= %w(-x test/ -x examples/)
  s.extra_rdoc_files = %w(README COPYING.txt)

  s.required_ruby_version	= '>= 1.9.0'
  s.add_runtime_dependency  'gssapi', '>= 0.1.5'
  s.add_runtime_dependency  'nokogiri'
  s.add_runtime_dependency  'httpclient'
  s.add_runtime_dependency  'rubyntlm'
  s.add_runtime_dependency  'uuid'
  s.add_runtime_dependency  'savon'
end
