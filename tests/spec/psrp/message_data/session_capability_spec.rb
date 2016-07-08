# encoding: UTF-8

require 'winrm/psrp/message_data/base'
require 'winrm/psrp/message_data/session_capability'

describe WinRM::PSRP::MessageData::SessionCapability do
  let(:protocol_version) { '2.2' }
  let(:ps_version) { '2.0' }
  let(:serialization_version) { '1.1.0.1' }
  let(:raw_data) do
    "\xEF\xBB\xBF<Obj RefId=\"0\"><MS>"\
      "<Version N=\"protocolversion\">#{protocol_version}</Version>"\
      "<Version N=\"PSVersion\">#{ps_version}</Version>"\
      "<Version N=\"SerializationVersion\">#{serialization_version}</Version></MS></Obj>"
  end

  subject { described_class.new(raw_data) }

  it 'parses protocol version' do
    expect(subject.protocol_version).to eq(protocol_version)
  end

  it 'parses ps version' do
    expect(subject.ps_version).to eq(ps_version)
  end

  it 'parses serialization version' do
    expect(subject.serialization_version).to eq(serialization_version)
  end
end
