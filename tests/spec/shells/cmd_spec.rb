# encoding: UTF-8

require 'winrm/shells/cmd'

describe WinRM::Shells::Cmd do
  let(:retry_limit) { 1 }
  let(:shell_id) { 'shell_id' }
  let(:output) { 'output' }
  let(:command_id) { 'command_id' }
  let(:command_payload) { 'command_payload' }
  let(:create_shell_payload) { 'create_shell_payload' }
  let(:close_shell_payload) { 'close_shell_payload' }
  let(:cleanup_payload) { 'cleanup_payload' }
  let(:command) { 'command' }
  let(:arguments) { ['args'] }
  let(:connection_options) { { max_commands: 100, retry_limit: retry_limit, retry_delay: 0 } }
  let(:transport) { double('transport') }

  before do
    allow_any_instance_of(WinRM::WSMV::Command).to receive(:command_id).and_return(command_id)
    allow_any_instance_of(WinRM::WSMV::Command).to receive(:build).and_return(command_payload)
    allow_any_instance_of(WinRM::WSMV::CloseShell).to receive(:build).and_return(close_shell_payload)
    allow_any_instance_of(WinRM::WSMV::CreateShell).to receive(:build).and_return(create_shell_payload)
    allow_any_instance_of(WinRM::WSMV::CleanupCommand).to receive(:build).and_return(cleanup_payload)
    allow_any_instance_of(WinRM::WSMV::CommandOutputProcessor).to receive(:command_output)
      .with(shell_id, command_id).and_return(output)
    allow(transport).to receive(:send_request).with(cleanup_payload)  
    allow(transport).to receive(:send_request).with(command_payload)
    allow(transport).to receive(:send_request).with(close_shell_payload)
    allow(transport).to receive(:send_request).with(create_shell_payload)
      .and_return(REXML::Document.new("<blah Name='ShellId'>#{shell_id}</blah>"))
  end

  subject { described_class.new(connection_options, transport, nil) }

  describe '#run' do
    it 'opens a shell and gets shell id' do
      subject.run(command, arguments)
      expect(subject.shell_id).to eq shell_id
    end

    it 'sends create shell through transport' do
      expect(transport).to receive(:send_request).with(create_shell_payload)
      subject.run(command, arguments)
    end

    it 'returns output from generated command' do
      expect(subject.run(command, arguments)).to eq output
    end

    it 'sends command through transport' do
      expect(transport).to receive(:send_request).with(command_payload)
      subject.run(command, arguments)
    end

    it 'sends cleanup message through transport' do
      expect(transport).to receive(:send_request).with(cleanup_payload)
      subject.run(command, arguments)
    end
  end

  describe '#close' do
    it 'sends close shell through transport' do
      subject.run(command, arguments)
      expect(transport).to receive(:send_request).with(close_shell_payload)
      subject.close
    end
  end
end
