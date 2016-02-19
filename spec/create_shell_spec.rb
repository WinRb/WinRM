# encoding: UTF-8

require_relative '../lib/winrm/wsmv/create_shell'

describe 'CreateShell', unit: true do
  context 'default session options' do
    session_opts = {
      endpoint: 'http://localhost:5985/wsman',
      max_envelope_size: 153600,
      session_id: '05A2622B-B842-4EB8-8A78-0225C8A993DF',
      operation_timeout: 60,
      locale: 'en-US'
    }
    it 'creates a well formed message' do
      xml = WinRM::WSMV::CreateShell.new(session_opts).build
      expect(xml).to include('<w:OperationTimeout>PT60S</w:OperationTimeout>')
      expect(xml).to include('<w:Locale xml:lang="en-US" mustUnderstand="false"/>')
      expect(xml).to include('<p:DataLocale xml:lang="en-US" mustUnderstand="false"/>')
      expect(xml).to include(
        '<p:SessionId mustUnderstand="false">' \
        'uuid:05A2622B-B842-4EB8-8A78-0225C8A993DF</p:SessionId>')
      expect(xml).to include('<w:MaxEnvelopeSize mustUnderstand="true">153600</w:MaxEnvelopeSize>')
      expect(xml).to include('<a:To>http://localhost:5985/wsman</a:To>')
      expect(xml).to include('<rsp:InputStreams>stdin</rsp:InputStreams>')
      expect(xml).to include('<rsp:OutputStreams>stdout stderr</rsp:OutputStreams>')
      expect(xml).to include(
        '<w:ResourceURI mustUnderstand="true">' \
        'http://schemas.microsoft.com/wbem/wsman/1/windows/shell/cmd</w:ResourceURI>')
    end
    context 'shell options' do
      let(:shell_opts) { Hash.new }
      it 'includes environemt vars' do
        shell_opts[:env_vars] = { 'FOO' => 'BAR' }
        xml = WinRM::WSMV::CreateShell.new(session_opts, shell_opts).build
        expect(xml).to include(
          '<rsp:Environment><rsp:Variable Name="FOO">BAR</rsp:Variable></rsp:Environment>')
      end
    end
  end
end
