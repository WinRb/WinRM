# encoding: UTF-8
require 'winrm/winrm_service'
require 'rexml/document'
require 'erb'

describe 'issue 184', unit: true do
  let(:shell_id)    { 'shell-123' }
  let(:command_id)  { 123 }
  let(:test_data_xml_template) do
    ERB.new(File.read('spec/stubs/responses/get_command_output_response.xml.erb'))
  end
  let(:service) do
    WinRM::WinRMWebService.new(
      'http://dummy/wsman',
      :plaintext,
      user: 'dummy',
      pass: 'dummy')
  end

  describe 'response doc stdout with invalid UTF-8 characters' do
    let(:test_data_stdout) { 'fff' } # Base64-decodes to '}\xF7', an invalid sequence
    let(:test_data_stderr) { '' }
    let(:test_data_xml) do
      test_data_xml_template.result(binding)
    end

    before do
      allow(service).to receive(:send_get_output_message).and_return(
        REXML::Document.new(test_data_xml)
      )
    end

    it 'does not raise an ArgumentError: invalid byte sequence in UTF-8' do
      begin
        expect(service.get_command_output(shell_id, command_id)).not_to raise_error
      rescue RSpec::Expectations::ExpectationNotMetError => e
        expect(e.message).not_to include 'ArgumentError'
      end
    end

    it 'does not have an empty stdout' do
      expect(service.get_command_output(shell_id, command_id)[:data][0][:stdout]).not_to be_empty
    end
  end
end
