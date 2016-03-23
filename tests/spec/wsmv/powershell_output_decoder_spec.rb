# encoding: UTF-8

require 'winrm/wsmv/powershell_output_decoder'

describe WinRM::WSMV::PowershellOutputDecoder do
  let(:message) do
    WinRM::PSRP::Message.new(
      object_id: 1,
      runspace_pool_id: 'bc1bfbba-8215-4a04-b2df-7a3ac0310e16',
      pipeline_id: '4218a578-0f18-4b19-82c3-46b433319126',
      message_type: WinRM::PSRP::Message::MESSAGE_TYPES[:error_record],
      data: data
    )
  end
  let(:encoded) { Base64.strict_encode64(message.bytes.pack('C*')) }

  subject { described_class.new.decode(encoded).last }

  context 'receiving output with BOM and no new line' do
    let(:data) { "\xEF\xBB\xBF<obj><S>some data</S></obj>" }

    it 'decodes removing BOM and adding newline' do
      expect(subject).to eq("some data\r\n")
    end
  end

  context 'receiving output with encoded new line' do
    let(:data) { '<obj><S>some data_x000D__x000A_</S></obj>' }

    it 'decodes without double newline' do
      expect(subject).to eq("some data\r\n")
    end
  end

  context 'receiving output with new line in middle' do
    let(:data) { '<obj><S>some_x000D__x000A_data</S></obj>' }

    it 'decodes and replaces newline' do
      expect(subject).to eq("some\r\ndata\r\n")
    end
  end

  context 'receiving error record' do
    let(:data) { %(<obj><S N="blah1">blahblah1</S><S N="blah2">blahblah2</S></obj>) }

    it 'decodes key value record' do
      expect(subject.split("\r\n")[0]).to eq('blah1: blahblah1')
      expect(subject.split("\r\n")[1]).to eq('blah2: blahblah2')
    end
  end
end
