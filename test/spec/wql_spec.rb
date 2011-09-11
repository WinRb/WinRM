$: << File.dirname(__FILE__)
require 'spec_helper'

describe "Test remote WQL features via WinRM" do
  before(:all) do
    @winrm = winrm_connection
  end

  it 'should run a WQL query against Win32_Service' do
    output = @winrm.run_wql('select Name,Status from Win32_Service')
    output.should_not be_empty
  end
end
