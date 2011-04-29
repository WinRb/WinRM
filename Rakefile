require 'rubygems'
require 'rake/clean'
require 'date'

CLEAN.include("pkg")
CLEAN.include("doc")
CLEAN.include("*.gem")

task :default => [:gem]

desc "Build the gem from the gemspec"
task :repackage do
    system "gem build winrm.gemspec"
end

desc "Build the gem without a version change"
task :gem => [:clean, :repackage]

desc "Increment the version by 1 minor release"
task :versionup do
	ver = up_min_version
	puts "New version: #{ver}"
end

desc "Build the gem, but increment the version first"
task :newrelease => [:versionup, :clean, :repackage]


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
