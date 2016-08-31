# encoding: UTF-8

require 'winrm/wsmv/create_shell'

describe WinRM::WSMV::CreateShell do
  context 'default session options' do
    subject { described_class.new(default_connection_opts) }
    let(:xml) { subject.build }
    it 'creates a well formed message' do
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
    context 'shell options w/env vars' do
      let(:shell_opts) do
        {
          env_vars: { 'FOO' => 'BAR' }
        }
      end
      subject { described_class.new(default_connection_opts, shell_opts) }
      let(:xml) { subject.build }
      it 'includes environemt vars' do
        expect(xml).to include(
          '<rsp:Environment><rsp:Variable Name="FOO">BAR</rsp:Variable></rsp:Environment>')
      end
    end
  end
end
