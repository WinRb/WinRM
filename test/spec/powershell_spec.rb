$: << File.dirname(__FILE__)
require 'spec_helper'

describe "Test remote Powershell features via WinRM" do
  before(:all) do
    @winrm = winrm_connection
  end

  it 'should run a test Powershell script' do
    ps_file = File.open("#{File.dirname(__FILE__)}/test.ps1", 'r+')
    output = @winrm.run_powershell_script(ps_file)
    ps_file.close
    output[:exitcode].should == 0
  end
end
