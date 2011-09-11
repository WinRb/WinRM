$: << File.dirname(__FILE__) + '/../../lib/'
require 'winrm'
require 'json'

module ConnectionHelper
  # To run this test put a file called 'creds.json' in this directory with the following format:
  #   {"user":"myuser","pass":"mypass","endpoint":"http://mysys.com/wsman","realm":"MY.REALM"}
  CREDS_FILE=File.dirname(__FILE__) + '/creds.json'

  def winrm_connection
    creds = JSON.load(File.open(CREDS_FILE,'r'))
    winrm = WinRM::WinRMWebService.new(creds['endpoint'], :kerberos, :realm => creds['realm'])
    #winrm = WinRM::WinRMWebService.new(creds['endpoint'], :plaintext, :user => creds['user'], :pass => creds['pass'])
    #winrm = WinRM::WinRMWebService.new(creds['endpoint'], :plaintext, :user => creds['user'], :pass => creds['pass'], :basic_auth_only => true)
    winrm
  end
end

RSpec.configure do |config|
  config.include(ConnectionHelper)
end
