# encoding: UTF-8

require 'winrm/psrp/fragment'

describe WinRM::PSRP::Fragment do
  let(:id) { 1 }
  let(:message) { 'blah blah blah' }

  context 'called with just id and blob' do
    subject { described_class.new(id, message.bytes) }

    it 'sets the message id to 1' do
      expect(subject.bytes[0..7]).to eq([0, 0, 0, 0, 0, 0, 0, id])
    end
    it 'sets the fragment id to 0' do
      expect(subject.bytes[8..15]).to eq([0, 0, 0, 0, 0, 0, 0, 0])
    end
    it 'sets the last 2 bits of the end/start fragment' do
      expect(subject.bytes[16]).to eq(3)
    end
    it 'sets message blob length to 3640' do
      expect(subject.bytes[17..20]).to eq([0, 0, 0, message.bytes.length])
    end
    it 'sets message blob' do
      expect(subject.bytes[21..-1]).to eq(message.bytes)
    end
  end

  context 'specifying a fragment id' do
    let(:fragment_id) { 1 }

    subject { described_class.new(id, message.bytes, fragment_id) }

    it 'sets the fragment id' do
      expect(subject.bytes[8..15]).to eq([0, 0, 0, 0, 0, 0, 0, fragment_id])
    end
  end

  context 'middle fragment' do
    subject { described_class.new(id, message.bytes, 1, false, false) }

    it 'sets the last 2 bits of the end/start fragment to 0' do
      expect(subject.bytes[16]).to eq(0)
    end
  end

  context 'end fragment' do
    subject { described_class.new(id, message.bytes, 1, true, false) }

    it 'sets the end fragment bit' do
      expect(subject.bytes[16]).to eq(1)
    end
  end

  context 'start fragment' do
    subject { described_class.new(id, message.bytes, 1, false, true) }

    it 'sets the start fragment bit' do
      expect(subject.bytes[16]).to eq(2)
    end
  end
end
