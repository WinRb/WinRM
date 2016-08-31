# encoding: UTF-8

require 'winrm/shells/power_shell'

describe WinRM::Shells::Powershell do
  let(:retry_limit) { 1 }
  let(:max_envelope_size_kb) { 150 }
  let(:shell_id) { 'bc1bfbba-8215-4a04-b2df-7a3ac0310e16' }
  let(:output) { 'output' }
  let(:command_id) { '4218A578-0F18-4B19-82C3-46B433319126' }
  let(:keepalive_payload) { 'keepalive_payload' }
  let(:configuration_payload) { 'configuration_payload' }
  let(:command_payload) { 'command_payload' }
  let(:create_shell_payload) { 'create_shell_payload' }
  let(:close_shell_payload) { 'close_shell_payload' }
  let(:cleanup_payload) { 'cleanup_payload' }
  let(:command) { 'command' }
  let(:output_message) { double('output_message', build: 'output_message') }
  let(:command_response) { "<a xmlns:rsp='foo'><rsp:CommandId>#{command_id}</rsp:CommandId></a>" }
  let(:configuration_response) do
    "<a xmlns:cfg='foo'><cfg:MaxEnvelopeSizekb>#{max_envelope_size_kb}</cfg:MaxEnvelopeSizekb></a>"
  end
  let(:connection_options) { { max_commands: 100, retry_limit: retry_limit, retry_delay: 0 } }
  let(:transport) { double('transport', send_request: nil) }
  let(:test_data_xml_template) do
    ERB.new(stubbed_response('get_powershell_keepalive_response.xml.erb'))
  end
  let(:protocol_version) { 2.2 }
  let(:test_data1) do
    <<-EOH
      <Obj RefId="0">
        <MS>
          <Version N="protocolversion">#{protocol_version}</Version>
          <Version N="PSVersion">2.0</Version>
          <Version N="SerializationVersion">1.1.0.1</Version>
        </MS>
      </Obj>
    EOH
  end
  let(:test_data2) { '<Obj RefId="0"><MS><I32 N="RunspaceState">2</I32></MS></Obj>' }
  let(:message1) do
    WinRM::PSRP::Message.new(
      shell_id,
      WinRM::PSRP::Message::MESSAGE_TYPES[:session_capability],
      test_data1,
      command_id
    )
  end
  let(:message2) do
    WinRM::PSRP::Message.new(
      shell_id,
      WinRM::PSRP::Message::MESSAGE_TYPES[:runspacepool_state],
      test_data2,
      command_id
    )
  end
  let(:fragment1) { WinRM::PSRP::Fragment.new(1, message1.bytes) }
  let(:fragment2) { WinRM::PSRP::Fragment.new(1, message2.bytes) }
  let(:test_data_stdout1) { Base64.strict_encode64(fragment1.bytes.pack('C*')) }
  let(:test_data_stdout2) { Base64.strict_encode64(fragment2.bytes.pack('C*')) }

  before do
    allow(SecureRandom).to receive(:uuid).and_return(command_id)
    allow(subject).to receive(:command_output_message).with(shell_id, command_id)
      .and_return(output_message)
    allow_any_instance_of(WinRM::WSMV::CreatePipeline).to receive(:build)
      .and_return(command_payload)
    allow_any_instance_of(WinRM::WSMV::CloseShell).to receive(:build)
      .and_return(close_shell_payload)
    allow_any_instance_of(WinRM::WSMV::InitRunspacePool).to receive(:build)
      .and_return(create_shell_payload)
    allow_any_instance_of(WinRM::WSMV::Configuration).to receive(:build)
      .and_return(configuration_payload)
    allow_any_instance_of(WinRM::WSMV::CleanupCommand).to receive(:build)
      .and_return(cleanup_payload)
    allow_any_instance_of(WinRM::WSMV::KeepAlive).to receive(:build).and_return(keepalive_payload)
    allow_any_instance_of(WinRM::PSRP::ReceiveResponseReader).to receive(:read_output)
      .with(output_message).and_return(output)
    allow(transport).to receive(:send_request).with(configuration_payload).and_return(
      REXML::Document.new(configuration_response))
    allow(transport).to receive(:send_request).with(create_shell_payload)
      .and_return(REXML::Document.new("<blah Name='ShellId'>#{shell_id}</blah>"))
    allow(transport).to receive(:send_request).with(command_payload)
      .and_return(REXML::Document.new(command_response))
    allow(transport).to receive(:send_request).with(keepalive_payload)
      .and_return(REXML::Document.new(test_data_xml_template.result(binding)))
  end

  subject { described_class.new(connection_options, transport, Logging.logger['test']) }

  describe '#run' do
    it 'opens a shell and gets shell id' do
      subject.run(command)
      expect(subject.shell_id).to eq shell_id
    end

    it 'sends create shell through transport' do
      expect(transport).to receive(:send_request).with(create_shell_payload)
      subject.run(command)
    end

    it 'sends keepalive shell through transport' do
      expect(transport).to receive(:send_request).with(keepalive_payload)
      subject.run(command)
    end

    it 'returns output from generated command' do
      expect(subject.run(command)).to eq output
    end

    it 'sends command through transport' do
      expect(transport).to receive(:send_request).with(command_payload)
      subject.run(command)
    end

    it 'sends cleanup message through transport' do
      expect(transport).to receive(:send_request).with(cleanup_payload)
      subject.run(command)
    end

    context 'non admin user' do
      before do
        allow(transport).to receive(:send_request).with(configuration_payload)
          .and_raise(WinRM::WinRMWSManFault.new('no access for you', '5'))
      end

      context 'protocol version 2.1' do
        let(:protocol_version) { 2.1 }

        it 'sets the fragmenter max_blob_length' do
          expect_any_instance_of(WinRM::PSRP::MessageFragmenter).to receive(:max_blob_length=)
            .with(153600)
          subject.run(command)
        end
      end

      context 'protocol version 2.2' do
        let(:protocol_version) { 2.2 }

        it 'sets the fragmenter max_blob_length' do
          expect_any_instance_of(WinRM::PSRP::MessageFragmenter).to receive(:max_blob_length=)
            .with(512000)
          subject.run(command)
        end
      end
    end

    context 'fragment large command' do
      let(:command) { 'c' * 200000 }

      it 'fragments messages as large as max envelope size' do
        allow_any_instance_of(WinRM::WSMV::CreatePipeline).to receive(:build).and_call_original
        allow(transport).to receive(:send_request).with(/CommandLine/) do |payload|
          expect(payload.length).to be max_envelope_size_kb * 1024
        end.and_return(REXML::Document.new(command_response))
        subject.run(command)
      end
    end
  end

  describe '#close' do
    it 'sends close shell through transport' do
      subject.run(command)
      expect(transport).to receive(:send_request).with(close_shell_payload)
      subject.close
    end

    it 'creates a shell closer with powershell uri' do
      allow(WinRM::WSMV::CloseShell).to receive(:new) do |_, opts|
        expect(opts[:shell_uri]).to be WinRM::WSMV::Header::RESOURCE_URI_POWERSHELL
      end.and_call_original
      subject.close
    end
  end
end
