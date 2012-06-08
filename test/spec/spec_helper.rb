$: << File.dirname(__FILE__) + '/../../lib/'
require 'winrm'
require 'json'

module ConnectionHelper
  # To run this test put a file called 'creds.json' in this directory with the following format:
  #   {"user":"myuser","pass":"mypass","endpoint":"http://mysys.com/wsman","realm":"MY.REALM"}
  WINRM_CONFIG = File.expand_path("#{File.dirname(__FILE__)}/../config.yml")

  def winrm_connection
    config = symbolize_keys(YAML.load(File.read(WINRM_CONFIG)))
    config[:options].merge!( :basic_auth_only => true ) unless config[:auth_type].eql? :kerberos
    winrm = WinRM::WinRMWebService.new(config[:endpoint], config[:auth_type].to_sym, config[:options])
    winrm
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
