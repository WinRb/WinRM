# encoding: UTF-8

require 'winrm/wsmv/command_output_processor'

describe WinRM::WSMV::CommandOutputProcessor do
  let(:shell_id) { 'F4A2622B-B842-4EB8-8A78-0225C8A993DF' }
  let(:command_id) { 'A2A2622B-B842-4EB8-8A78-0225C8A993DF' }
  let(:test_data_xml_template) do
    ERB.new(stubbed_response('get_command_output_response.xml.erb'))
  end
  let(:transport) do
    {}
  end

  subject do
    described_class.new(
      default_connection_opts,
      transport,
      WinRM::WSMV::CommandOutputDecoder.new,
      Logging.logger
    )
  end

  context 'response doc stdout with invalid UTF-8 characters, issue 184' do
    let(:test_data_stdout) { 'ffff' } # Base64-decodes to '}\xF7\xDF', an invalid sequence
    let(:test_data_stderr) { '' }
    let(:test_data_xml)    { test_data_xml_template.result(binding) }

    before do
      allow(transport).to receive(:send_request).and_return(
        REXML::Document.new(test_data_xml)
      )
    end

    it 'does not raise an ArgumentError: invalid byte sequence in UTF-8' do
      begin
        expect(
          subject.command_output(shell_id, command_id)
        ).not_to raise_error
      rescue RSpec::Expectations::ExpectationNotMetError => e
        expect(e.message).not_to include 'ArgumentError'
      end
    end

    it 'does not have an empty stdout' do
      expect(
        subject.command_output(shell_id, command_id)[:data][0][:stdout]
      ).not_to be_empty
    end
  end

  context 'response doc stdout with valid UTF-8' do
    let(:test_data_raw)    { '✓1234-äöü' }
    let(:test_data_stdout) { Base64.encode64(test_data_raw) }
    let(:test_data_stderr) { '' }
    let(:test_data_xml)    { test_data_xml_template.result(binding) }

    before do
      allow(transport).to receive(:send_request).and_return(
        REXML::Document.new(test_data_xml)
      )
    end

    it 'decodes to match input data' do
      expect(
        subject.command_output(shell_id, command_id)[:data][0][:stdout]
      ).to eq(test_data_raw)
    end
  end
end
