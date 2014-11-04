require 'rubygems'
require 'bundler/setup'
require 'winrm'
require 'json'
require_relative 'matchers'

module ConnectionHelper

  def winrm_connection
    config = symbolize_keys(YAML.load(File.read(winrm_config_path)))
    config[:options].merge!( :basic_auth_only => true ) unless config[:auth_type].eql? :kerberos
    winrm = WinRM::WinRMWebService.new(config[:endpoint], config[:auth_type].to_sym, config[:options])
    winrm
  end

  def winrm_config_path
    # Copy config-example.yml to config.yml and edit for your local configuration
    path = File.expand_path("#{File.dirname(__FILE__)}/config.yml")
    if !File.exists?(path)
      # user hasn't done this, so use sane defaults for unit tests
      path = File.expand_path("#{File.dirname(__FILE__)}/config-example.yml")
    end
    path
  end

  def symbolize_keys(hash)
    hash.inject({}){|result, (key, value)|
      new_key = case key
                when String then key.to_sym
                else key
                end
      new_value = case value
                  when Hash then symbolize_keys(value)
                  else value
                  end
      result[new_key] = new_value
      result
    }
  end

end

RSpec.configure do |config|
  config.include(ConnectionHelper)
end
