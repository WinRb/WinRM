# encoding: UTF-8
require 'rubygems'
require 'bundler/setup'
require 'winrm'
require 'json'
require_relative '../matchers'

module SpecUnitHelper
  def stubbed_response(file)
    File.read("tests/spec/stubs/responses/#{file}")
  end

  def default_session_opts
    {
      endpoint: 'http://localhost:5985/wsman',
      max_envelope_size: 153600,
      session_id: '05A2622B-B842-4EB8-8A78-0225C8A993DF',
      operation_timeout: 60,
      locale: 'en-US'
    }
  end
end

# Strip leading whitespace from each line that is the same as the
# amount of whitespace on the first line of the string.
# Leaves _additional_ indentation on later lines intact.
# and remove newlines.
class String
  def unindent
    gsub(/^#{self[/\A[ \t]*/]}/, '').gsub("\n", '')
  end
end

RSpec.configure do |config|
  config.include(SpecUnitHelper)
end
