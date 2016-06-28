# encoding: UTF-8

require 'winrm/psrp/message_data/base'
require 'winrm/psrp/message_data/error_record'

describe WinRM::PSRP::MessageData::ErrorRecord do
  let(:test_data_xml_template) do
    ERB.new(stubbed_clixml('error_record.xml.erb'))
  end
  let(:error_message) { 'an error' }
  let(:raw_data) { test_data_xml_template.result(binding) }
  subject { described_class.new(raw_data) }

  it 'replace with a real test' do
    expect(subject.raw).to eq(raw_data)
  end
end
