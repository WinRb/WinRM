# encoding: UTF-8
describe 'winrm client primitives' do
  before(:all) do
    @winrm = winrm_connection
  end

  describe 'open and close shell', integration: true do
    it 'should #open_shell and #close_shell' do
      sid = @winrm.open_shell
      expect(sid).to be_a_uid
      expect(@winrm.close_shell(sid)).to be true
    end

    it 'should #run_command and #cleanup_command' do
      sid = @winrm.open_shell

      cmd_id = @winrm.run_command(sid, 'ipconfig', %w(/all))
      expect(sid).to be_a_uid

      expect(@winrm.cleanup_command(sid, cmd_id)).to be true
      @winrm.close_shell(sid)
    end

    it 'should #get_command_output' do
      sid = @winrm.open_shell
      cmd_id = @winrm.run_command(sid, 'ipconfig', %w(/all))

      output = @winrm.get_command_output(sid, cmd_id)
      expect(output).to have_exit_code 0
      expect(output).to have_stdout_match(/.+/)
      expect(output).to have_no_stderr

      @winrm.cleanup_command(sid, cmd_id)
      @winrm.close_shell(sid)
    end

    it 'should #get_command_output with a block' do
      sid = @winrm.open_shell
      cmd_id = @winrm.run_command(sid, 'ipconfig', %w(/all))

      outvar = ''
      @winrm.get_command_output(sid, cmd_id) do |stdout, _stderr|
        outvar << stdout
      end
      expect(outvar).to match(/Windows IP Configuration/)

      @winrm.cleanup_command(sid, cmd_id)
      @winrm.close_shell(sid)
    end
  end
end
