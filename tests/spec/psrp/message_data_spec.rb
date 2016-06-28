# encoding: UTF-8

require 'winrm/psrp/message'
require 'winrm/psrp/message_data'

describe WinRM::PSRP::MessageData do
  describe '#parse' do
    let(:raw_data) { 'raw_data' }
    let(:message) do
      WinRM::PSRP::Message.new(
        '00000000-0000-0000-0000-000000000000',
        message_type,
        raw_data
      )
    end

    subject { WinRM::PSRP::MessageData.parse(message) }

    context 'defined message type' do
      let(:message_type) { WinRM::PSRP::Message::MESSAGE_TYPES[:pipeline_output] }

      it 'creates correct message data type' do
        expect(subject).to be_a(WinRM::PSRP::MessageData::PipelineOutput)
      end
    end

    context 'undefined message type' do
      let(:message_type) { WinRM::PSRP::Message::MESSAGE_TYPES[:pipeline_input] }

      it 'returns nill' do
        expect(subject).to be nil
      end
    end
  end
end
