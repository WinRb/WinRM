# encoding: UTF-8

require 'base64'
require 'winrm/wsmv/write_stdin'

describe 'WriteStdin', unit: true do
  context 'default session options' do
    session_opts = {
      endpoint: 'http://localhost:5985/wsman',
      max_envelope_size: 153600,
      session_id: '05A2622B-B842-4EB8-8A78-0225C8A993DF',
      operation_timeout: 60,
      locale: 'en-US'
    }
    stdin_opts = {
      shell_id: 'D5A2622B-B842-4EB8-8A78-0225C8A993DF',
      command_id: 'A2A2622B-B842-4EB8-8A78-0225C8A993DF',
      stdin: 'dir'
    }
    it 'creates a well formed message' do
      xml = WinRM::WSMV::WriteStdin.new(session_opts, stdin_opts).build
      b64_stdin = Base64.encode64(stdin_opts[:stdin])
      expect(xml).to include('<w:OperationTimeout>PT60S</w:OperationTimeout>')
      expect(xml).to include('<rsp:Stream Name="stdin" ' \
        "CommandId=\"A2A2622B-B842-4EB8-8A78-0225C8A993DF\">#{b64_stdin}</rsp:Stream>")
    end
  end
end
