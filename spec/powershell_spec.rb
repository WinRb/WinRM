describe "Test remote Powershell features via WinRM", :integration => true do
  before(:all) do
    @winrm = winrm_connection
  end

  it 'should run a test Powershell script' do
    ps_file = File.open("#{File.dirname(__FILE__)}/test.ps1", 'r+')
    output = @winrm.run_powershell_script(ps_file)
    ps_file.close
    expect(output[:exitcode]).to eq(0)
  end
end
