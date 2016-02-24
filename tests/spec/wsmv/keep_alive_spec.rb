# encoding: UTF-8

require 'winrm/wsmv/keep_alive'

describe WinRM::WSMV::KeepAlive do
  context 'default session options' do
    let(:shell_id) { 'F4A2622B-B842-4EB8-8A78-0225C8A993DF' }
    subject { described_class.new(default_connection_opts, shell_id) }
    let(:xml) { subject.build }
    it 'creates a well formed message' do
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
