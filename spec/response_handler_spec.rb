# encoding: UTF-8
require 'winrm/http/response_handler'

describe 'response handler', unit: true do
  %w(v1, v2).each do |winrm_version|
    let(:soap_fault) { File.read("spec/stubs/responses/soap_fault_#{winrm_version}.xml") }
    let(:open_shell) { File.read("spec/stubs/responses/open_shell_#{winrm_version}.xml") }

    describe "successful 200 #{winrm_version} response" do
      it 'returns an xml doc' do
        handler = WinRM::ResponseHandler.new(open_shell, 200)
        xml_doc = handler.parse_to_xml
        expect(xml_doc).to be_instance_of(REXML::Document)
        expect(xml_doc.to_s).to eq(REXML::Document.new(open_shell).to_s)
      end
    end

    describe "failed 500 #{winrm_version} response" do
      it 'raises a WinRMHTTPTransportError' do
        handler = WinRM::ResponseHandler.new('', 500)
        expect { handler.parse_to_xml }.to raise_error(WinRM::WinRMHTTPTransportError)
      end
    end

    describe "failed 401 #{winrm_version} response" do
      it 'raises a WinRMAuthorizationError' do
        handler = WinRM::ResponseHandler.new('', 401)
        expect { handler.parse_to_xml }.to raise_error(WinRM::WinRMAuthorizationError)
      end
    end

    describe "failed 400 #{winrm_version} response" do
      it 'raises a WinRMWSManFault' do
        handler = WinRM::ResponseHandler.new(soap_fault, 400)
        begin
          handler.parse_to_xml
        rescue WinRM::WinRMWSManFault => e
          expect(e.fault_code).to eq('2150858778')
          expect(e.fault_description).to include(
            'The specified class does not exist in the given namespace')
        end
      end
    end
  end

  describe 'failed 500 WMI error response' do
    let(:wmi_error) { File.read('spec/stubs/responses/wmi_error_v2.xml') }

    it 'raises a WinRMWMIError' do
      handler = WinRM::ResponseHandler.new(wmi_error, 500)
      begin
        handler.parse_to_xml
      rescue WinRM::WinRMWMIError => e
        expect(e.error_code).to eq('2150859173')
        expect(e.error).to include('The WS-Management service cannot process the request.')
      end
    end
  end
end
