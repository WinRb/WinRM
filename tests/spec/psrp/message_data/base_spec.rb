# encoding: UTF-8

require 'winrm/psrp/message_data/base'

describe WinRM::PSRP::MessageData::Base do
  let(:raw_data) { 'raw_data' }

  subject { WinRM::PSRP::MessageData::Base.new(raw_data) }

  it 'holds raw message data' do
    expect(subject.raw).to eq(raw_data)
  end
end
