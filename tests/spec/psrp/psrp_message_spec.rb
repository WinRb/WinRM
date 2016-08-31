# encoding: UTF-8

require 'winrm/psrp/message'

describe WinRM::PSRP::Message do
  context 'all fields provided' do
    let(:payload) { 'this is my payload' }
    subject do
      described_class.new(
        'bc1bfbba-8215-4a04-b2df-7a3ac0310e16',
        WinRM::PSRP::Message::MESSAGE_TYPES[:pipeline_output],
        payload,
        '4218a578-0f18-4b19-82c3-46b433319126')
    end

    it 'sets the destination to server LE' do
      expect(subject.bytes[0..3]).to eq([2, 0, 0, 0])
    end
    it 'sets the message type LE' do
      expect(subject.bytes[4..7]).to eq([4, 16, 4, 0])
    end
    it 'sets the runspace pool id' do
      expect(subject.bytes[8..23]).to eq(
        [186, 251, 27, 188, 21, 130, 4, 74, 178, 223, 122, 58, 192, 49, 14, 22])
    end
    it 'sets the pipeline id' do
      expect(subject.bytes[24..39]).to eq(
        [120, 165, 24, 66, 24, 15, 25, 75, 130, 195, 70, 180, 51, 49, 145, 38])
    end
    it 'prefixes the blob with BOM' do
      expect(subject.bytes[40..42]).to eq([239, 187, 191])
    end
    it 'contains at least the first 8 bytes of the XML payload' do
      expect(subject.bytes[43..-1]).to eq(payload.bytes)
    end
    it 'parses the data' do
      expect(subject.parsed_data).to be_a(WinRM::PSRP::MessageData::PipelineOutput)
    end
  end

  context 'create' do
    it 'raises error when message type is not valid' do
      expect do
        WinRM::PSRP::Message.new(
          'bc1bfbba-8215-4a04-b2df-7a3ac0310e16',
          0x00000000,
          %(<Obj RefId="0"/>),
          '4218a578-0f18-4b19-82c3-46b433319126')
      end.to raise_error(RuntimeError)
    end
  end

  context 'no command id' do
    subject(:msg) do
      payload = <<-HERE.unindent
        <Obj RefId="0"><MS><Version N="protocolversion">2.3</Version>
        <Version N="PSVersion">2.0</Version><Version N="SerializationVersion">1.1.0.1</Version></MS>
        </Obj>
      HERE
      WinRM::PSRP::Message.new(
        'bc1bfbba-8215-4a04-b2df-7a3ac0310e16',
        WinRM::PSRP::Message::MESSAGE_TYPES[:session_capability],
        payload)
    end

    it 'sets the pipeline id to empty' do
      expect(msg.bytes[24..39]).to eq([0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0])
    end
  end
end
