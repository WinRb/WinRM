# encoding: UTF-8

require 'winrm/psrp/message_defragmenter'

describe WinRM::PSRP::MessageDefragmenter do
  let(:bytes) do
    "\x00\x00\x00\x00\x00\x00\x00\x04\x00\x00\x00\x00\x00\x00\x00\x01\x03\x00\x00\x00I\x01"\
    "\x00\x00\x00\x04\x10\x04\x00Kk/=Z\xD3-E\x81v\xA0+6\xB1\xD3\x88\n\xED\x90\x9Cj\xE7PG"\
    "\x9F\xA2\xB2\xC99to9\xEF\xBB\xBF<S>some data_x000D__x000A_</S>".to_byte_string
  end
  subject { described_class.new.defragment(Base64.encode64(bytes)) }

  it 'parses the data' do
    expect(subject.data).to eq("\xEF\xBB\xBF<S>some data_x000D__x000A_</S>".to_byte_string)
  end

  it 'parses the destination' do
    expect(subject.destination).to eq(1)
  end

  it 'parses the message type' do
    expect(subject.type).to eq(WinRM::PSRP::Message::MESSAGE_TYPES[:pipeline_output])
  end
end
