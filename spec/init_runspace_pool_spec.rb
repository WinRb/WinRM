# encoding: UTF-8

require_relative '../lib/winrm/wsmv/init_runspace_pool'

describe 'InitRunspacePool', unit: true do
  context 'default session options' do
    let(:session_opts) do
      {
        endpoint: 'http://localhost:5985/wsman',
        max_envelope_size: 153600,
        session_id: '05A2622B-B842-4EB8-8A78-0225C8A993DF',
        operation_timeout: 60,
        locale: 'en-US'
      }
    end
    let(:creation_xml) do
      session_capabilities = WinRM::PSRP::MessageFactory.session_capability_message(
        1, subject.shell_id)
      runspace_init = WinRM::PSRP::MessageFactory.init_runspace_pool_message(1, subject.shell_id)
      Base64.strict_encode64((session_capabilities.bytes + runspace_init.bytes).pack('C*'))
    end

    subject { WinRM::WSMV::InitRunspacePool.new(session_opts) }

    it 'creates a well formed message' do
      xml = subject.build
      expect(xml).to include('<w:OperationTimeout>PT60S</w:OperationTimeout>')
      expect(xml).to include('<w:Locale xml:lang="en-US" mustUnderstand="false"/>')
      expect(xml).to include('<p:DataLocale xml:lang="en-US" mustUnderstand="false"/>')
      expect(xml).to include(
        '<p:SessionId mustUnderstand="false">' \
        'uuid:05A2622B-B842-4EB8-8A78-0225C8A993DF</p:SessionId>')
      expect(xml).to include('<w:MaxEnvelopeSize mustUnderstand="true">153600</w:MaxEnvelopeSize>')
      expect(xml).to include('<a:To>http://localhost:5985/wsman</a:To>')
      expect(xml).to include(
        '<w:OptionSet env:mustUnderstand="true">' \
        '<w:Option Name="protocolversion" MustComply="true">2.3</w:Option></w:OptionSet>')
      expect(xml).to include('<rsp:InputStreams>stdin pr</rsp:InputStreams>')
      expect(xml).to include('<rsp:OutputStreams>stdout</rsp:OutputStreams>')
      expect(xml).to include("<rsp:Shell ShellId=\"#{subject.shell_id}\">")
      expect(xml).to include(
        '<w:ResourceURI mustUnderstand="true">' \
        'http://schemas.microsoft.com/powershell/Microsoft.PowerShell')
      expect(xml).to include(
        '<creationXml xmlns="http://schemas.microsoft.com/powershell">' \
        "#{creation_xml}</creationXml>")
    end
  end
end
