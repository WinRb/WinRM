# encoding: UTF-8
describe WinRM::PSRP::Message do
  context 'all fields provided' do
    subject(:bytes) do
      msg = WinRM::PSRP::Message.new(
        1,
        'bc1bfbba-8215-4a04-b2df-7a3ac0310e16',
        '4218a578-0f18-4b19-82c3-46b433319126',
        0x00010002,
        %(<Obj RefId="0"></Obj>))
      msg.bytes
    end
    it 'sets the message id to 1' do
      expect(bytes[0..7]).to eq([0, 0, 0, 0, 0, 0, 0, 1])
    end
    it 'sets the fragment id to 0' do
      expect(bytes[8..15]).to eq([0, 0, 0, 0, 0, 0, 0, 0])
    end
    it 'clears 6 reserved bits' do
      expect(bytes[16] & 0b11111100).to eq(0)
    end
    it 'sets end fragment bit' do
      expect(bytes[16] & 0b00000010).to eq(2)
    end
    it 'sets start fragment bit' do
      expect(bytes[16] & 0b00000001).to eq(1)
    end
    it 'sets message blob length to 3640' do
      expect(bytes[17..20]).to eq([0, 0, 14, 56])
    end
    it 'sets the destination to server LE' do
      expect(bytes[21..24]).to eq([2, 0, 0, 0])
    end
    it 'sets the message type LE' do
      expect(bytes[25..28]).to eq([2, 0, 1, 0])
    end
    it 'sets the runspace pool id' do
      expect(bytes[29..44]).to eq(
        [186, 251, 27, 188, 21, 130, 4, 74, 178, 223, 122, 58, 192, 49, 14, 22])
    end
    it 'sets the pipeline id' do
      expect(bytes[45..60]).to eq(
        [120, 165, 24, 66, 24, 15, 25, 75, 130, 195, 70, 180, 51, 49, 145, 38])
    end
    it 'prefixes the blob with BOM' do
      expect(bytes[61..63]).to eq([239, 187, 191])
    end
    it 'contains at least the first 8 bytes of the XML payload' do
      expect(bytes[64..71]).to eq([60, 79, 98, 106, 32, 82, 101, 102])
    end
  end
  context 'create' do
    it 'raises error when shell id is nil' do
      expect do
        WinRM::PSRP::Message.new(
          1,
          nil,
          '4218a578-0f18-4b19-82c3-46b433319126',
          0x00010002,
          %(<Obj RefId="0"/>))
      end.to raise_error(RuntimeError)
    end
    it 'raises error when message type is not valid' do
      expect do
        WinRM::PSRP::Message.new(
          1,
          'bc1bfbba-8215-4a04-b2df-7a3ac0310e16',
          '4218a578-0f18-4b19-82c3-46b433319126',
          0x00000000,
          %(<Obj RefId="0"/>))
      end.to raise_error(RuntimeError)
    end
    it 'raises error when payload is nil' do
      expect do
        WinRM::PSRP::Message.new(
          1,
          'bc1bfbba-8215-4a04-b2df-7a3ac0310e16',
          '4218a578-0f18-4b19-82c3-46b433319126',
          0x00010002,
          nil)
      end.to raise_error(RuntimeError)
    end
  end
  context 'no command id' do
    subject(:msg) do
      WinRM::PSRP::Message.new(
        1,
        'bc1bfbba-8215-4a04-b2df-7a3ac0310e16',
        nil,
        0x00010002,
        %(<Obj RefId="0"></Obj>))
    end
    it 'does not error' do
      expect { msg.bytes }.to_not raise_error
    end
    it 'sets the pipeline id to empty' do
      expect(msg.bytes[45..60]).to eq([0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0])
    end
  end
end
