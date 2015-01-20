# encoding: UTF-8
describe 'issue 59', integration: true do
  before(:all) do
    @winrm = winrm_connection
  end

  describe 'long running script without output' do
    it 'should not error' do
      output = @winrm.powershell('sleep 60; Write-Host "Hello"')
      expect(output).to have_exit_code 0
      expect(output).to have_stdout_match(/Hello/)
      expect(output).to have_no_stderr
    end
  end
end
