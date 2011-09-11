$: << File.dirname(__FILE__)
require 'spec_helper'

describe "Test WinRM primitive methods" do
  before(:all) do
    @winrm = winrm_connection
  end

  it 'should #open_shell and #close_shell' do
    sid = @winrm.open_shell
    # match a UUID
    sid.should =~ /^\w{8}-\w{4}-\w{4}-\w{4}-\w{12}$/
    @winrm.close_shell(sid).should be_true
  end

  it 'should #run_command and #cleanup_command' do
    sid = @winrm.open_shell

    cmd_id = @winrm.run_command(sid, 'ipconfig', %w{/all})
    cmd_id.should =~ /^\w{8}-\w{4}-\w{4}-\w{4}-\w{12}$/

    @winrm.cleanup_command(sid, cmd_id).should be_true
    @winrm.close_shell(sid)
  end

  it 'should #get_command_output' do
    sid = @winrm.open_shell
    cmd_id = @winrm.run_command(sid, 'ipconfig', %w{/all})

    output = @winrm.get_command_output(sid, cmd_id)
    output[:exitcode].should == 0
    output[:data].should_not be_empty

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
    outvar.should =~ /Windows IP Configuration/

    @winrm.cleanup_command(sid, cmd_id)
    @winrm.close_shell(sid)
  end

  it 'should set #op_timeout' do
    @winrm.op_timeout(120).should == 'PT2M0S'
    @winrm.op_timeout(1202).should == 'PT20M2S'
    @winrm.op_timeout(86400).should == 'PT24H0S'
  end

  it 'should set #max_env_size' do
    @winrm.max_env_size(153600 * 4)
    @winrm.instance_variable_get('@max_env_sz').should == 614400
  end

  it 'should set #locale' do
    @winrm.locale('en-ca')
    @winrm.instance_variable_get('@locale').should == 'en-ca'
  end

end
