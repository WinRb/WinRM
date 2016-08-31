# encoding: UTF-8

require 'winrm/shells/cmd'

describe WinRM::Shells::Cmd do
  let(:retry_limit) { 1 }
  let(:shell_id) { 'shell_id' }
  let(:output) { 'output' }
  let(:create_shell_payload) { 'create_shell_payload' }
  let(:close_shell_payload) { 'close_shell_payload' }
  let(:cleanup_payload) { 'cleanup_payload' }
  let(:command) { 'run this command' }
  let(:arguments) { ['args'] }
  let(:command_response) { "<a xmlns:rsp='foo'><rsp:CommandId>command_id</rsp:CommandId></a>" }
  let(:connection_options) { { max_commands: 100, retry_limit: retry_limit, retry_delay: 0 } }
  let(:transport) { double('transport', send_request: nil) }

  before do
    allow_any_instance_of(WinRM::WSMV::CloseShell).to receive(:build)
      .and_return(close_shell_payload)
    allow_any_instance_of(WinRM::WSMV::CreateShell).to receive(:build)
      .and_return(create_shell_payload)
    allow_any_instance_of(WinRM::WSMV::CleanupCommand).to receive(:build)
      .and_return(cleanup_payload)
    allow_any_instance_of(WinRM::WSMV::ReceiveResponseReader).to receive(:read_output)
      .and_return(output)
    allow(transport).to receive(:send_request).with(create_shell_payload)
      .and_return(REXML::Document.new("<blah Name='ShellId'>#{shell_id}</blah>"))
    allow(transport).to receive(:send_request).with(/#{command}/)
      .and_return(REXML::Document.new(command_response))
  end

  subject { described_class.new(connection_options, transport, Logging.logger['test']) }

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
      expect(transport).to receive(:send_request).with(/#{command}/)
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

    it 'creates a shell closer with default shell uri' do
      allow(WinRM::WSMV::CloseShell).to receive(:new) do |_, opts|
        expect(opts[:shell_uri]).to be nil
      end.and_call_original
      subject.close
    end
  end
end
