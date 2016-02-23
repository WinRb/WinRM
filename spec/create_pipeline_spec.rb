# encoding: UTF-8

require_relative '../lib/winrm/wsmv/create_pipeline'

describe 'CreatePipeline', unit: true do
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
    let(:shell_id) { 'D5A2622B-B842-4EB8-8A78-0225C8A993DF' }
    let(:command) { 'ipconfig' }
    let(:pipeline) do
      message = WinRM::PSRP::MessageFactory.create_pipeline_message(
        3, shell_id, subject.command_id, command)
      Base64.strict_encode64(message.bytes.pack('C*'))
    end

    subject { WinRM::WSMV::CreatePipeline.new(session_opts, shell_id, command) }

    it 'creates a well formed message' do
      xml = subject.build
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
