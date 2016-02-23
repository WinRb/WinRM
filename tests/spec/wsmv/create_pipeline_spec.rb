# encoding: UTF-8

require 'winrm/wsmv/create_pipeline'

describe WinRM::WSMV::CreatePipeline do
  context 'default session options' do
    let(:shell_id) { 'D5A2622B-B842-4EB8-8A78-0225C8A993DF' }
    let(:command) { 'ipconfig' }
    let(:pipeline) do
      message = WinRM::PSRP::MessageFactory.create_pipeline_message(
        3, shell_id, subject.command_id, command)
      Base64.strict_encode64(message.bytes.pack('C*'))
    end
    subject { WinRM::WSMV::CreatePipeline.new(default_session_opts, shell_id, command) }
    let(:xml) { subject.build }
    it 'creates a well formed message' do
      expect(xml).to include('<w:OperationTimeout>PT60S</w:OperationTimeout>')
      expect(xml).to include(
        '<w:SelectorSet><w:Selector Name="ShellId">' \
        "#{shell_id}</w:Selector></w:SelectorSet>")
      expect(xml).to include("<rsp:CommandLine CommandId=\"#{subject.command_id}\">")
      expect(xml).to include('<rsp:Command>Invoke-Expression</rsp:Command>')
      expect(xml).to include("<rsp:Arguments>#{pipeline}</rsp:Arguments>")
    end
  end
end
