describe "Test remote WQL features via WinRM", :integration => true do
  before(:all) do
    @winrm = winrm_connection
  end

  it 'should run a WQL query against Win32_Service' do
    output = @winrm.run_wql('select Name,Status from Win32_Service')
    expect(output).to_not be_empty
  end
end
