# encoding: UTF-8
describe 'issue 59', integration: true do
  before(:all) do
    @winrm = winrm_connection
  end

  describe 'long running script without output' do
    let(:logged_output) { StringIO.new }
    let(:logger)        { Logging.logger(logged_output) }

    it 'should not error' do
      @winrm.set_timeout(1)
      @winrm.logger = logger

      out = @winrm.powershell('$ProgressPreference="SilentlyContinue";sleep 3; Write-Host "Hello"')

      expect(out).to have_exit_code 0
      expect(out).to have_stdout_match(/Hello/)
      expect(out).to have_no_stderr
      expect(logged_output.string).to match(/retrying receive request/)
    end
  end
end
