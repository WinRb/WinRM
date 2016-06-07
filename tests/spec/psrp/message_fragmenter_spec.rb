# encoding: UTF-8

require 'winrm/psrp/message'
require 'winrm/psrp/message_fragmenter'

describe WinRM::PSRP::MessageFragmenter do
  let(:message) do
    WinRM::PSRP::Message.new(
      'bc1bfbba-8215-4a04-b2df-7a3ac0310e16',
      WinRM::PSRP::Message::MESSAGE_TYPES[:session_capability],
      data
    )
  end

  subject do
    fragmenter = described_class.new(45)
    fragments = []
    fragmenter.fragment(message) do |fragment|
      fragments.push(fragment)
    end
    fragments
  end

  context 'one fragment' do
    let(:data) { 'th' }

    it 'returns 1 fragment' do
      expect(subject.length).to eq(1)
    end

    it 'has blob data equal to the message bytes' do
      expect(subject[0].blob.length).to eq(message.bytes.length)
    end

    it 'identifies the fragment as start and end' do
      expect(subject[0].start_fragment).to eq(true)
      expect(subject[0].end_fragment).to eq(true)
    end

    it 'assigns fragment id correctly' do
      expect(subject[0].fragment_id).to eq(0)
    end
  end

  context 'two fragments' do
    let(:data) { 'This is a fragmented message' }

    it 'splits the message' do
      expect(subject.length).to eq(2)
    end

    it 'has a sum of blob data equal to the message bytes' do
      expect(subject[0].blob.length + subject[1].blob.length).to eq(message.bytes.length)
    end

    it 'identifies the first fragment as start and not end' do
      expect(subject[0].start_fragment).to eq(true)
      expect(subject[0].end_fragment).to eq(false)
    end

    it 'identifies the first fragment as start and not end' do
      expect(subject[1].start_fragment).to eq(false)
      expect(subject[1].end_fragment).to eq(true)
    end

    it 'assigns incementing fragment ids' do
      expect(subject[0].fragment_id).to eq(0)
      expect(subject[1].fragment_id).to eq(1)
    end
  end

  context 'three fragments' do
    let(:data) { 'This is a fragmented message because framents are lovely' }

    it 'splits the message' do
      expect(subject.length).to eq(3)
    end

    it 'has a sum of blob data equal to the message bytes' do
      expect(subject[0].blob.length + subject[1].blob.length + subject[2].blob.length)
        .to eq(message.bytes.length)
    end

    it 'identifies the first fragment as start and not end' do
      expect(subject[0].start_fragment).to eq(true)
      expect(subject[0].end_fragment).to eq(false)
    end

    it 'identifies the first fragment as start and not end' do
      expect(subject[1].start_fragment).to eq(false)
      expect(subject[1].end_fragment).to eq(false)
    end

    it 'identifies the third fragment as not start and end' do
      expect(subject[2].start_fragment).to eq(false)
      expect(subject[2].end_fragment).to eq(true)
    end

    it 'assigns incementing fragment ids' do
      expect(subject[0].fragment_id).to eq(0)
      expect(subject[1].fragment_id).to eq(1)
      expect(subject[2].fragment_id).to eq(2)
    end
  end
end
