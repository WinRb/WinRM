# encoding: UTF-8

require 'winrm/wsmv/keep_alive'

describe 'KeepAlive' do
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
    let(:shell_id) { 'F4A2622B-B842-4EB8-8A78-0225C8A993DF' }

    it 'creates a well formed message' do
      xml = WinRM::WSMV::KeepAlive.new(session_opts, shell_id).build
      expect(xml).to include('<w:OperationTimeout>PT60S</w:OperationTimeout>')
      expect(xml).to include(
        '<w:OptionSet><w:Option Name="WSMAN_CMDSHELL_OPTION_KEEPALIVE">' \
        'TRUE</w:Option></w:OptionSet>')
      expect(xml).to include(
        '<w:SelectorSet><w:Selector Name="ShellId">' \
        "#{shell_id}</w:Selector></w:SelectorSet>")
      expect(xml).to include('<rsp:DesiredStream>stdout</rsp:DesiredStream>')
    end
  end
end
