# encoding: UTF-8

require 'winrm/wsmv/command_output'
require 'winrm/wsmv/header'

describe WinRM::WSMV::CommandOutput do
  context 'default session options' do
    let(:cmd_out_opts) do
      {
        shell_id: 'F4A2622B-B842-4EB8-8A78-0225C8A993DF',
        command_id: 'A2A2622B-B842-4EB8-8A78-0225C8A993DF'
      }
    end
    subject { described_class.new(default_connection_opts, cmd_out_opts) }
    let(:xml) { subject.build }
    it 'creates a well formed message' do
      expect(xml).to include('<w:OperationTimeout>PT60S</w:OperationTimeout>')
      expect(xml).to include('<w:Option Name="WSMAN_CMDSHELL_OPTION_KEEPALIVE">TRUE</w:Option>')
      expect(xml).to include('w:ResourceURI mustUnderstand="true">' \
        'http://schemas.microsoft.com/wbem/wsman/1/windows/shell/cmd</w:ResourceURI>')
      expect(xml).to include('<rsp:DesiredStream ' \
        'CommandId="A2A2622B-B842-4EB8-8A78-0225C8A993DF">stdout stderr</rsp:DesiredStream>')
    end
  end
  context 'powershell' do
    let(:cmd_out_opts) do
      {
        shell_id: 'F4A2622B-B842-4EB8-8A78-0225C8A993DF',
        command_id: 'A2A2622B-B842-4EB8-8A78-0225C8A993DF',
        shell_uri: WinRM::WSMV::Header::RESOURCE_URI_POWERSHELL,
        out_streams: %w(stdout)
      }
    end
    subject { described_class.new(default_connection_opts, cmd_out_opts) }
    let(:xml) { subject.build }
    it 'creates a well formed message' do
      expect(xml).to include('<w:OperationTimeout>PT60S</w:OperationTimeout>')
      expect(xml).to include('<w:Option Name="WSMAN_CMDSHELL_OPTION_KEEPALIVE">TRUE</w:Option>')
      expect(xml).to include('w:ResourceURI mustUnderstand="true">' \
        'http://schemas.microsoft.com/powershell/Microsoft.PowerShell</w:ResourceURI>')
      expect(xml).to include('<rsp:DesiredStream ' \
        'CommandId="A2A2622B-B842-4EB8-8A78-0225C8A993DF">stdout</rsp:DesiredStream>')
    end
  end
end
