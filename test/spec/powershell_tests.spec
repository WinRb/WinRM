$: << File.dirname(__FILE__) + '/../../lib/'
require 'kconv'
require 'winrm'
require 'json'

# To run this test put a file called 'creds.json' in this directory with the following format:
#   {"user":"myuser","pass":"mypass","endpoint":"http://mysys.com/wsman"}


describe "Test remote Powershell features via WinRM" do
  before(:all) do
    creds = JSON.load(File.open('spec/creds.json','r'))
    WinRM::WinRM.endpoint = creds['endpoint']
    WinRM::WinRM.set_auth(creds['user'],creds['pass'])
    WinRM::WinRM.instance
  end

  it 'should run a test Powershell script' do
    winrm = WinRM::WinRM.instance
    output = winrm.powershell('spec/test.ps1')
    output[:exitcode].should eql(0)
  end

end
