# encoding: UTF-8

require 'winrm/wsmv/close_shell'

describe 'CloseShell' do
  context 'default session options' do
    session_opts = {
      endpoint: 'http://localhost:5985/wsman',
      max_envelope_size: 153600,
      session_id: '05A2622B-B842-4EB8-8A78-0225C8A993DF',
      operation_timeout: 60,
      locale: 'en-US'
    }
    cmd_opts = {
      shell_id: 'F4A2622B-B842-4EB8-8A78-0225C8A993DF'
    }
    it 'creates a well formed message' do
      xml = WinRM::WSMV::CloseShell.new(session_opts, cmd_opts).build
      expect(xml).to include('<w:OperationTimeout>PT60S</w:OperationTimeout>')
      expect(xml).to include('<a:Action mustUnderstand="true">' \
        'http://schemas.xmlsoap.org/ws/2004/09/transfer/Delete</a:Action>')
    end
  end
end
