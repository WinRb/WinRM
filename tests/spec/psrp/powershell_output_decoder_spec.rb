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

  context 'receiving pipeline state' do
    let(:message_type) { WinRM::PSRP::Message::MESSAGE_TYPES[:pipeline_state] }

    it 'ignores message' do
      expect(subject).to be nil
    end
  end

  context 'receiving information record' do
    let(:message_type) { WinRM::PSRP::Message::MESSAGE_TYPES[:information_record] }

    it 'ignores message' do
      expect(subject).to be nil
    end
  end

  context 'receiving progress record' do
    let(:message_type) { WinRM::PSRP::Message::MESSAGE_TYPES[:progress_record] }

    it 'ignores message' do
      expect(subject).to be nil
    end
  end

  context 'receiving host call to WriteProgress' do
    let(:message_type) { WinRM::PSRP::Message::MESSAGE_TYPES[:pipeline_host_call] }
    let(:data) { '<ToString>WriteProgress</ToString>' }

    it 'ignores message' do
      expect(subject).to be nil
    end
  end

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
