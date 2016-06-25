# encoding: UTF-8

require 'winrm/psrp/receive_response_reader'

describe WinRM::PSRP::ReceiveResponseReader do
  let(:shell_id) { 'F4A2622B-B842-4EB8-8A78-0225C8A993DF' }
  let(:command_id) { 'A2A2622B-B842-4EB8-8A78-0225C8A993DF' }
  let(:output_message) { double('output_message', build: 'output_message') }
  let(:test_data_xml_template) do
    ERB.new(stubbed_response('get_powershell_output_response.xml.erb'))
  end
  let(:test_data_text) { 'some data' }
  let(:test_data) { "<obj><S>#{test_data_text}</S></obj>" }
  let(:message) do
    WinRM::PSRP::Message.new(
      shell_id,
      message_type,
      test_data,
      command_id
    )
  end
  let(:fragment) { WinRM::PSRP::Fragment.new(1, message.bytes) }
  let(:test_data_stdout) { Base64.strict_encode64(fragment.bytes.pack('C*')) }
  let(:transport) { {} }

  before do
    allow(transport).to receive(:send_request).and_return(
      REXML::Document.new(test_data_xml_template.result(binding))
    )
  end

  subject do
    described_class.new(
      transport,
      Logging.logger['test']
    )
  end

  context 'response doc stdout with pipeline output' do
    let(:message_type) { WinRM::PSRP::Message::MESSAGE_TYPES[:pipeline_output] }

    it 'outputs to stdout' do
      expect(
        subject.read_output(output_message)[:data][0][:stdout]
      ).to eq("#{test_data_text}\r\n")
    end
  end

  context 'response doc stdout error record' do
    let(:message_type) { WinRM::PSRP::Message::MESSAGE_TYPES[:error_record] }

    it 'outputs to stderr' do
      expect(
        subject.read_output(output_message)[:data][0][:stderr]
      ).to eq("#{test_data_text}\r\n")
    end
  end

  context 'response doc writing error to host' do
    let(:message_type) { WinRM::PSRP::Message::MESSAGE_TYPES[:pipeline_host_call] }
    let(:test_data) do
      "<Obj RefId='0'><MS><I64 N='ci'>-100</I64><Obj N='mi' RefId='1'><TN RefId='0'>" \
      '<T>System.Management.Automation.Remoting.RemoteHostMethodId</T><T>System.Enum</T>' \
      '<T>System.ValueType</T><T>System.Object</T></TN><ToString>WriteErrorLine</ToString>' \
      "<I32>18</I32></Obj><Obj N='mp' RefId='2'><TN RefId='1'>" \
      '<T>System.Collections.ArrayList</T><T>System.Object</T></TN><LST><S>errors</S></LST></Obj>' \
      '</MS></Obj>'
    end

    it 'outputs to stderr' do
      expect(
        subject.read_output(output_message)[:data][0][:stderr]
      ).to eq("errors\r\n")
    end
  end

  context 'response doc writing output to host' do
    let(:message_type) { WinRM::PSRP::Message::MESSAGE_TYPES[:pipeline_host_call] }
    let(:test_data) do
      "<Obj RefId='0'><MS><I64 N='ci'>-100</I64><Obj N='mi' RefId='1'><TN RefId='0'>" \
      '<T>System.Management.Automation.Remoting.RemoteHostMethodId</T><T>System.Enum</T>' \
      '<T>System.ValueType</T><T>System.Object</T></TN><ToString>WriteHostLine</ToString>' \
      "<I32>18</I32></Obj><Obj N='mp' RefId='2'><TN RefId='1'>" \
      '<T>System.Collections.ArrayList</T><T>System.Object</T></TN><LST><S>output</S></LST></Obj>' \
      '</MS></Obj>'
    end

    it 'outputs to stdout' do
      expect(
        subject.read_output(output_message)[:data][0][:stdout]
      ).to eq("output\r\n")
    end
  end
end
