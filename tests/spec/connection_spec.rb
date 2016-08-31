# encoding: UTF-8

require 'winrm'
require 'winrm/shells/cmd'
require 'winrm/shells/power_shell'

describe WinRM::Connection do
  context 'new' do
    it 'creates a new winrm session' do
      connection = WinRM::Connection.new(default_connection_opts)
      expect(connection).not_to be_nil
    end
  end

  context 'shell(:cmd)' do
    it 'creates a new cmd session' do
      connection = WinRM::Connection.new(default_connection_opts)
      cmd_shell = connection.shell(:cmd)
      expect(cmd_shell).not_to be_nil
      expect(cmd_shell).to be_an_instance_of(WinRM::Shells::Cmd)
    end
  end

  context 'shell(:powershell)' do
    it 'creates a new powershell session' do
      connection = WinRM::Connection.new(default_connection_opts)
      cmd_shell = connection.shell(:powershell)
      expect(cmd_shell).not_to be_nil
      expect(cmd_shell).to be_an_instance_of(WinRM::Shells::Powershell)
    end
  end

  context 'shell(:not_a_real_shell_type)' do
    it 'raises a descriptive error' do
      connection = WinRM::Connection.new(default_connection_opts)
      expect { connection.shell(:not_a_real_shell_type) }.to raise_error(WinRM::InvalidShellError)
    end
  end
end
