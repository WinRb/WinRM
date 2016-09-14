# encoding: UTF-8

require 'winrm/psrp/message_data/base'
require 'winrm/psrp/message_data/pipeline_state'

describe WinRM::PSRP::MessageData::PipelineState do
  let(:test_data_xml_template) do
    ERB.new(stubbed_clixml('pipeline_state.xml.erb'))
  end
  let(:pipeline_state) { WinRM::PSRP::MessageData::PipelineState::FAILED }
  let(:error_message) { 'an error occured' }
  let(:category_message) { 'category message' }
  let(:error_id) { 'an error occured' }
  let(:raw_data) { test_data_xml_template.result(binding) }
  subject { described_class.new(raw_data) }

  it 'returns the state' do
    expect(subject.pipeline_state).to eq(pipeline_state)
  end

  it 'returns the exception' do
    expect(subject.exception_as_error_record.exception[:message]).to eq(error_message)
  end

  it 'returns the FullyQualifiedErrorId' do
    expect(subject.exception_as_error_record.fully_qualified_error_id).to eq(error_id)
  end

  it 'returns the error category message' do
    expect(subject.exception_as_error_record.error_category_message).to eq(category_message)
  end

  context 'state is not failed' do
    let(:pipeline_state) { WinRM::PSRP::MessageData::PipelineState::COMPLETED }

    it 'has a nil exception' do
      expect(subject.exception_as_error_record).to be(nil)
    end
  end
end
