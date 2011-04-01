require 'spec_helper'

describe "Test remote Powershell features via WinRM" do
  before(:all) do
    @winrm = winrm_connection
  end

  it 'should run a test Powershell script' do
    ps_file = File.open('spec/test.ps1', 'r+')
    output = @winrm.run_powershell_script(File.open('spec/test.ps1'))
    ps_file.close
    output[:exitcode].should == 0
  end
end
