$: << File.dirname(__FILE__) + '/../../lib/'
require 'kconv'
require 'winrm'
require 'json'

# To run this test put a file called 'creds.json' in this directory with the following format:
#   {"user":"myuser","pass":"mypass","endpoint":"http://mysys.com/wsman"}


describe "Test remote WQL features via WinRM" do
  before(:all) do
    creds = JSON.load(File.open('spec/creds.json','r'))
    WinRM::WinRM.endpoint = creds['endpoint']
    WinRM::WinRM.set_auth(creds['user'],creds['pass'])
    WinRM::WinRM.set_ca_trust_path('/etc/ssl/certs')
    WinRM::WinRM.instance
  end

  it 'should run a WQL query against Win32_Service' do
    winrm = WinRM::WinRM.instance
    output = winrm.wql('select Name,Status from Win32_Service')
    output.should_not be_empty
  end
end
