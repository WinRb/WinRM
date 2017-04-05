# encoding: UTF-8

require 'winrm/shells/base'

# Dummy shell class
class DummyShell < WinRM::Shells::Base
  class << self
    def finalize(connection_opts, transport, shell_id)
      proc { DummyShell.close_shell(connection_opts, transport, shell_id) }
    end

    def close_shell(_connection_opts, _transport, _shell_id)
      @closed = true
    end

    def closed?
      @closed
    end
  end

  def open_shell
    @closed = false
    'shell_id'
  end

  def send_command(_command, _arguments)
    'command_id'
  end

  def out_streams
    %w(std)
  end
end

describe DummyShell do
  let(:retry_limit) { 1 }
  let(:shell_id) { 'shell_id' }
  let(:output) { 'output' }
  let(:command_id) { 'command_id' }
  let(:payload) { 'message_payload' }
  let(:command) { 'command' }
  let(:arguments) { ['args'] }
  let(:output_message) { double('output_message', build: 'output_message') }
  let(:connection_options) { { max_commands: 100, retry_limit: retry_limit, retry_delay: 0 } }
  let(:transport) { double('transport') }
  let(:reader) { double('reader') }

  before do
    allow(subject).to receive(:response_reader).and_return(reader)
    allow(subject).to receive(:command_output_message).with(shell_id, command_id)
      .and_return(output_message)
    allow(reader).to receive(:read_output).with(output_message).and_return(output)
    allow(transport).to receive(:send_request)
  end

  subject { described_class.new(connection_options, transport, Logging.logger['test']) }

  shared_examples 'retry shell command' do
    it 'only closes the shell if there are too many' do
      if fault == WinRM::Shells::Base::TOO_MANY_COMMANDS
        expect(DummyShell).to receive(:close_shell)
      else
        expect(DummyShell).not_to receive(:close_shell)
      end

      subject.run(command, arguments)
    end

    it 'opens a new shell' do
      expect(subject).to receive(:open).and_call_original.twice

      subject.run(command, arguments)
    end

    it 'retries the command once' do
      expect(subject).to receive(:send_command).twice

      subject.run(command, arguments)
    end
  end

  describe '#run' do
    it 'opens a shell' do
      subject.run(command, arguments)
      expect(subject.shell_id).not_to be nil
    end

    it 'returns output from generated command' do
      expect(subject.run(command, arguments)).to eq output
    end

    it 'sends cleanup message through transport' do
      allow(SecureRandom).to receive(:uuid).and_return('uuid')
      expect(transport).to receive(:send_request)
        .with(
          WinRM::WSMV::CleanupCommand.new(
            connection_options,
            shell_uri: nil,
            shell_id: shell_id,
            command_id: command_id
          ).build
        )
      subject.run(command, arguments)
    end

    it 'does not error if cleanup is aborted' do
      allow(SecureRandom).to receive(:uuid).and_return('uuid')
      expect(transport).to receive(:send_request)
        .with(
          WinRM::WSMV::CleanupCommand.new(
            connection_options,
            shell_uri: nil,
            shell_id: shell_id,
            command_id: command_id
          ).build
        ).and_raise(WinRM::WinRMWSManFault.new('oops', '995'))
      subject.run(command, arguments)
    end

    it 'does not error if shell is not present anymore' do
      allow(SecureRandom).to receive(:uuid).and_return('uuid')
      expect(transport).to receive(:send_request)
        .with(
          WinRM::WSMV::CleanupCommand.new(
            connection_options,
            shell_uri: nil,
            shell_id: shell_id,
            command_id: command_id
          ).build
        ).and_raise(WinRM::WinRMWSManFault.new('oops', '2150858843'))
      subject.run(command, arguments)
    end

    it 'opens a shell only once when shell is already open' do
      expect(subject).to receive(:open_shell).and_call_original.once
      subject.run(command, arguments)
      subject.run(command, arguments)
    end

    describe 'connection resets' do
      before do
        @times_called = 0

        allow(subject).to receive(:send_command) do
          @times_called += 1
          raise WinRM::WinRMWSManFault.new('oops', fault) if @times_called == 1
          command_id
        end
      end

      context 'when shell is closed on server' do
        let(:fault) { '2150858843' }

        include_examples 'retry shell command'
      end

      context 'when shell accesses a deleted registry key' do
        let(:fault) { '2147943418' }

        include_examples 'retry shell command'
      end

      context 'when maximum number of concurrent shells is exceeded' do
        let(:fault) { '2150859174' }

        include_examples 'retry shell command'
      end
    end

    context 'open_shell fails' do
      let(:retry_limit) { 2 }
      let(:output_message2) { double('message') }

      it 'retries and raises failure if it never succeeds' do
        expect(subject).to receive(:open_shell)
          .and_raise(Errno::ECONNREFUSED).exactly(retry_limit).times
        expect { subject.run(command) }.to raise_error(Errno::ECONNREFUSED)
      end

      it 'retries and returns shell on success' do
        @times = 0
        allow(subject).to receive(:command_output_message).with('shell_id 2', command_id)
          .and_return(output_message2)
        allow(reader).to receive(:read_output)
          .with(output_message2).and_return(output)
        allow(subject).to receive(:open_shell) do
          @times += 1
          raise(Errno::ECONNREFUSED) if @times == 1
          "shell_id #{@times}"
        end

        subject.run(command, arguments)
        expect(subject.shell_id).to eq 'shell_id 2'
      end
    end
  end

  describe '#close' do
    it 'does not close if not opened' do
      expect(DummyShell).not_to receive(:close_shell)
      subject.close
    end

    it 'close shell if opened' do
      subject.run(command, arguments)
      subject.close
      expect(DummyShell.closed?).to be(true)
    end

    it 'nils out the shell_id' do
      subject.run(command, arguments)
      subject.close
      expect(subject.shell_id).to be(nil)
    end

    context 'when shell was not found' do
      it 'does not raise' do
        subject.run(command, arguments)
        expect(DummyShell).to receive(:close_shell)
          .and_raise(WinRM::WinRMWSManFault.new('oops', '2150858843'))
        expect { subject.close }.not_to raise_error
      end
    end
  end
end
