describe "Test WinRM primitive methods" do
  before(:all) do
    @winrm = winrm_connection
  end

  describe "open and close shell", :integration => true do

    it 'should #open_shell and #close_shell' do
      sid = @winrm.open_shell
      # match a UUID
      expect(sid).to match(/^\w{8}-\w{4}-\w{4}-\w{4}-\w{12}$/)
      expect(@winrm.close_shell(sid)).to be true
    end

    it 'should #run_command and #cleanup_command' do
      sid = @winrm.open_shell

      cmd_id = @winrm.run_command(sid, 'ipconfig', %w{/all})
      expect(sid).to match(/^\w{8}-\w{4}-\w{4}-\w{4}-\w{12}$/)

      expect(@winrm.cleanup_command(sid, cmd_id)).to be true
      @winrm.close_shell(sid)
    end

    it 'should #get_command_output' do
      sid = @winrm.open_shell
      cmd_id = @winrm.run_command(sid, 'ipconfig', %w{/all})

      output = @winrm.get_command_output(sid, cmd_id)
      expect(output[:exitcode]).to eq(0)
      expect(output[:data]).to_not be_empty

      @winrm.cleanup_command(sid, cmd_id)
      @winrm.close_shell(sid)
    end
    
    it 'should #get_command_output with a block' do
      sid = @winrm.open_shell
      cmd_id = @winrm.run_command(sid, 'ipconfig', %w{/all})

      outvar = ''
      @winrm.get_command_output(sid, cmd_id) do |stdout, stderr|
        outvar << stdout
      end
      expect(outvar).to match(/Windows IP Configuration/)

      @winrm.cleanup_command(sid, cmd_id)
      @winrm.close_shell(sid)
    end
  end

  describe "simple values", :unit => true do
    it 'should set #op_timeout' do
      expect(@winrm.op_timeout(120)).to eq('PT2M0S')
      expect(@winrm.op_timeout(1202)).to eq('PT20M2S')
      expect(@winrm.op_timeout(86400)).to eq('PT24H0S')
    end

    it 'should set #max_env_size' do
      @winrm.max_env_size(153600 * 4)
      expect(@winrm.instance_variable_get('@max_env_sz')).to eq(614400)
    end

    it 'should set #locale' do
      @winrm.locale('en-ca')
      expect(@winrm.instance_variable_get('@locale')).to eq('en-ca')
    end
  end

end
