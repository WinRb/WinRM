# encoding: UTF-8

require 'winrm/wsmv/cleanup_command'

describe WinRM::WSMV::CleanupCommand do
  context 'default session options' do
    let(:cmd_opts) do
      {
        shell_id: 'F4A2622B-B842-4EB8-8A78-0225C8A993DF',
        command_id: 'A2A2622B-B842-4EB8-8A78-0225C8A993DF'
      }
    end
    subject { described_class.new(default_connection_opts, cmd_opts) }
    let(:xml) { subject.build }
    it 'creates a well formed message' do
      expect(xml).to include('<w:OperationTimeout>PT60S</w:OperationTimeout>')
      expect(xml).to include('<rsp:Signal CommandId="A2A2622B-B842-4EB8-8A78-0225C8A993DF">' \
        '<rsp:Code>http://schemas.microsoft.com/wbem/wsman/1/windows/shell/signal/terminate' \
        '</rsp:Code></rsp:Signal>')
    end
  end
end
