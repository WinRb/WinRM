$: << File.dirname(__FILE__)
require 'spec_helper'

describe "Test remote WQL features via WinRM" do
  before(:all) do
    @winrm = winrm_connection
  end

  it 'should run a CMD command string' do
    output = @winrm.run_cmd('ipconfig /all')
    output[:exitcode].should == 0
    output[:data].should_not be_empty
  end

  it 'should run a CMD command with proper arguments' do
    output = @winrm.run_cmd('ipconfig', %w{/all})
    output[:exitcode].should == 0
    output[:data].should_not be_empty
  end

  it 'should run a CMD command with block' do
    outvar = ''
    @winrm.run_cmd('ipconfig', %w{/all}) do |stdout, stderr|
      outvar << stdout
    end
    outvar.should =~ /Windows IP Configuration/
  end
end
