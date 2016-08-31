# encoding: UTF-8
require_relative 'spec_helper'

describe 'issue 59' do
  describe 'long running script without output' do
    let(:logged_output) { StringIO.new }
    let(:logger)        { Logging.logger(logged_output) }

    before do
      opts = connection_opts.dup
      opts[:operation_timeout] = 1
      conn = WinRM::Connection.new(opts)
      conn.logger = logger
      @powershell = conn.shell(:powershell)
    end

    it 'should not error' do
      out = @powershell.run('$ProgressPreference="SilentlyContinue";sleep 3; Write-Host "Hello"')

      expect(out).to have_exit_code 0
      expect(out).to have_stdout_match(/Hello/)
      expect(out).to have_no_stderr
      expect(logged_output.string).to match(/retrying receive request/)
    end
  end
end
