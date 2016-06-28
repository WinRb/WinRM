# encoding: UTF-8

require 'winrm/psrp/message_data/base'
require 'winrm/psrp/message_data/pipeline_output'

describe WinRM::PSRP::MessageData::PipelineOutput do
  subject { described_class.new(raw_data) }

  context 'receiving output with BOM and no new line' do
    let(:raw_data) { "\xEF\xBB\xBF<obj><S>some data</S></obj>" }

    it 'output removes BOM and adds newline' do
      expect(subject.output).to eq("some data\r\n")
    end
  end

  context 'receiving output with encoded new line' do
    let(:raw_data) { '<obj><S>some data_x000D__x000A_</S></obj>' }

    it 'decodes without double newline' do
      expect(subject.output).to eq("some data\r\n")
    end
  end

  context 'receiving output with new line in middle' do
    let(:raw_data) { '<obj><S>some_x000D__x000A_data</S></obj>' }

    it 'decodes and replaces newline' do
      expect(subject.output).to eq("some\r\ndata\r\n")
    end
  end
end
