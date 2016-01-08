# encoding: UTF-8
describe 'issue 59', integration: true do
  before(:all) do
    @winrm = winrm_connection
  end

  describe 'long running script without output' do
    it 'should not error' do
      out = @winrm.powershell('$ProgressPreference="SilentlyContinue";sleep 60; Write-Host "Hello"')
      expect(out).to have_exit_code 0
      expect(out).to have_stdout_match(/Hello/)
      expect(out).to have_no_stderr
    end
  end
end
