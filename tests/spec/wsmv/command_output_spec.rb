# encoding: UTF-8

require 'winrm/wsmv/command_output'

describe 'CommandOutput' do
  context 'default session options' do
    session_opts = {
      endpoint: 'http://localhost:5985/wsman',
      max_envelope_size: 153600,
      session_id: '05A2622B-B842-4EB8-8A78-0225C8A993DF',
      operation_timeout: 60,
      locale: 'en-US'
    }
    cmd_out_opts = {
      shell_id: 'F4A2622B-B842-4EB8-8A78-0225C8A993DF',
      command_id: 'A2A2622B-B842-4EB8-8A78-0225C8A993DF'
    }
    it 'creates a well formed message' do
      xml = WinRM::WSMV::CommandOutput.new(session_opts, cmd_out_opts).build
      expect(xml).to include('<w:OperationTimeout>PT60S</w:OperationTimeout>')
      expect(xml).to include('<w:Option Name="WSMAN_CMDSHELL_OPTION_KEEPALIVE">TRUE</w:Option>')
      expect(xml).to include('<rsp:DesiredStream ' \
        'CommandId="A2A2622B-B842-4EB8-8A78-0225C8A993DF">stdout stderr</rsp:DesiredStream>')
    end
  end
end
