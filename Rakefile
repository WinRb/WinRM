require 'rubygems'
require 'rake/clean'
require 'rake/gempackagetask'
require 'date'

CLEAN.include("pkg")
CLEAN.include("doc")

GEMSPEC = Gem::Specification.new do |gem|
  gem.name = "winrm"
  gem.version = File.open('VERSION').readline.chomp
  gem.date		= Date.today.to_s
  gem.platform = Gem::Platform::RUBY
  gem.rubyforge_project  = nil

  gem.author = "Dan Wanek"
  gem.email = "dan.wanek@gmail.com"
  gem.homepage = "http://github.com/zenchild/WinRM"

  gem.summary = 'Ruby library for Windows Remote Management'
  gem.description	= <<-EOF
    Ruby library for Windows Remote Management
  EOF

  gem.files = `git ls-files`.split(/\n/)
  gem.require_path = "lib"
  gem.rdoc_options	= %w(-x test/ -x examples/)
  gem.extra_rdoc_files = %w(README COPYING.txt)

  gem.required_ruby_version	= '>= 1.8.7'
  gem.add_runtime_dependency  'handsoap'
  gem.add_runtime_dependency  'nokogiri'
  gem.add_runtime_dependency  'httpclient'
  gem.add_runtime_dependency  'rubyntlm'
  gem.add_runtime_dependency  'uuid'
end
 
Rake::GemPackageTask.new(GEMSPEC) do |pkg|
  pkg.need_tar = true
end

task :default => [:buildgem]

desc "Build the gem without a version change"
task :buildgem => [:clean, :repackage]

desc "Build the gem, but increment the version first"
task :newrelease => [:versionup, :clean, :repackage]


desc "Increment the version by 1 minor release"
task :versionup do
	ver = up_min_version
	puts "New version: #{ver}"
end


def up_min_version
	f = File.open('VERSION', 'r+')
	ver = f.readline.chomp
	v_arr = ver.split(/\./).map do |v|
		v.to_i
	end
	v_arr[2] += 1
	ver = v_arr.join('.')
	f.rewind
	f.write(ver)
	ver
end
