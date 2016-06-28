# encoding: UTF-8

require 'winrm/psrp/powershell_output_decoder'

describe WinRM::PSRP::PowershellOutputDecoder do
  let(:message_type) { WinRM::PSRP::Message::MESSAGE_TYPES[:error_record] }
  let(:data) { 'blah' }
  let(:message) do
    WinRM::PSRP::Message.new(
      'bc1bfbba-8215-4a04-b2df-7a3ac0310e16',
      message_type,
      data,
      '4218a578-0f18-4b19-82c3-46b433319126'
    )
  end

  subject { described_class.new.decode(message) }

  context 'undecodable message type' do
    let(:message_type) { WinRM::PSRP::Message::MESSAGE_TYPES[:pipeline_state] }

    it 'ignores message' do
      expect(subject).to be nil
    end
  end

  context 'undecodable method identifier' do
    let(:message_type) { WinRM::PSRP::Message::MESSAGE_TYPES[:pipeline_host_call] }
    let(:data) do
      "\xEF\xBB\xBF<Obj RefId=\"0\"><MS><I64 N=\"ci\">-100</I64><Obj N=\"mi\" RefId=\"1\">"\
      '<TN RefId="0"><T>System.Management.Automation.Remoting.RemoteHostMethodId</T>'\
      '<T>System.Enum</T><T>System.ValueType</T><T>System.Object</T></TN>'\
      '<ToString>WriteProgress</ToString><I32>17</I32></Obj><Obj N="mp" RefId="2">'\
      '<TN RefId="1"><T>System.Collections.ArrayList</T><T>System.Object</T></TN><LST>'\
      '<I32>7</I32><I32>0</I32><S>some_x000D__x000A_data</S></LST></Obj></MS></Obj>'
    end

    it 'ignores message' do
      expect(subject).to be nil
    end
  end

  context 'receiving pipeline output' do
    let(:message_type) { WinRM::PSRP::Message::MESSAGE_TYPES[:pipeline_output] }
    let(:data) { '<obj><S>some data</S></obj>' }

    it 'decodes output' do
      expect(subject).to eq("some data\r\n")
    end
  end

  context 'writeline with new line in middle' do
    let(:message_type) { WinRM::PSRP::Message::MESSAGE_TYPES[:pipeline_host_call] }
    let(:data) do
      "\xEF\xBB\xBF<Obj RefId=\"0\"><MS><I64 N=\"ci\">-100</I64><Obj N=\"mi\" RefId=\"1\">"\
      '<TN RefId="0"><T>System.Management.Automation.Remoting.RemoteHostMethodId</T>'\
      '<T>System.Enum</T><T>System.ValueType</T><T>System.Object</T></TN>'\
      '<ToString>WriteLine3</ToString><I32>17</I32></Obj><Obj N="mp" RefId="2">'\
      '<TN RefId="1"><T>System.Collections.ArrayList</T><T>System.Object</T></TN><LST>'\
      '<I32>7</I32><I32>0</I32><S>some_x000D__x000A_data</S></LST></Obj></MS></Obj>'
    end

    it 'decodes and replaces newline' do
      expect(subject).to eq("some\r\ndata\r\n")
    end
  end

  context 'receiving error record' do
    let(:message_type) { WinRM::PSRP::Message::MESSAGE_TYPES[:error_record] }
    let(:data) { %(<obj><S N="blah1">blahblah1</S><S N="blah2">blahblah2</S></obj>) }

    it 'decodes key value record' do
      expect(subject.split("\r\n")[0]).to eq('blah1: blahblah1')
      expect(subject.split("\r\n")[1]).to eq('blah2: blahblah2')
    end
  end
end
