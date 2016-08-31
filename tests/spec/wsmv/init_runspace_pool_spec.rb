# encoding: UTF-8

require 'winrm/wsmv/init_runspace_pool'

describe WinRM::WSMV::InitRunspacePool do
  context 'default session options' do
    let(:shell_id) { SecureRandom.uuid.to_s.upcase }
    let(:payload) { 'blah'.bytes }

    subject { described_class.new(default_connection_opts, shell_id, payload) }

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
        "#{Base64.strict_encode64(payload.pack('C*'))}</creationXml>")
    end
  end
end
