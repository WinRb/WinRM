# encoding: UTF-8

require 'winrm/psrp/message_data/base'
require 'winrm/psrp/message_data/error_record'

describe WinRM::PSRP::MessageData::ErrorRecord do
  let(:test_data_xml_template) do
    ERB.new(stubbed_clixml('error_record.xml.erb'))
  end
  let(:error_message) { 'an error' }
  let(:script_root) { 'script_root' }
  let(:category_message) { 'category message' }
  let(:stack_trace) { 'stack trace' }
  let(:error_id) { 'Microsoft.PowerShell.Commands.WriteErrorException' }
  let(:raw_data) { test_data_xml_template.result(binding) }
  subject { described_class.new(raw_data) }

  it 'returns the exception' do
    expect(subject.exception[:message]).to eq(error_message)
  end

  it 'returns the FullyQualifiedErrorId' do
    expect(subject.fully_qualified_error_id).to eq(error_id)
  end

  it 'returns the invocation info' do
    expect(subject.invocation_info[:line]).to eq("write-error '#{error_message}'")
  end

  it 'converts camel case properties to underscore' do
    expect(subject.invocation_info[:ps_script_root]).to eq(script_root)
  end

  it 'returns the error category message' do
    expect(subject.error_category_message).to eq(category_message)
  end

  it 'returns the script stack trace' do
    expect(subject.error_details_script_stack_trace).to eq(stack_trace)
  end
end
