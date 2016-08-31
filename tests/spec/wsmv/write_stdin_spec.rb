# encoding: UTF-8

require 'base64'
require 'winrm/wsmv/write_stdin'

describe WinRM::WSMV::WriteStdin do
  context 'default session options' do
    stdin_opts = {
      shell_id: 'D5A2622B-B842-4EB8-8A78-0225C8A993DF',
      command_id: 'A2A2622B-B842-4EB8-8A78-0225C8A993DF',
      stdin: 'dir'
    }
    subject { described_class.new(default_connection_opts, stdin_opts) }
    let(:xml) { subject.build }
    it 'creates a well formed message' do
      b64_stdin = Base64.encode64(stdin_opts[:stdin])
      expect(xml).to include('<w:OperationTimeout>PT60S</w:OperationTimeout>')
      expect(xml).to include('<rsp:Stream Name="stdin" ' \
        "CommandId=\"A2A2622B-B842-4EB8-8A78-0225C8A993DF\">#{b64_stdin}</rsp:Stream>")
    end
  end
end
