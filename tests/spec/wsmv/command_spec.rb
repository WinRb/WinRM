# encoding: UTF-8

require 'winrm/wsmv/command'

describe WinRM::WSMV::Command do
  context 'default session options' do
    let(:cmd_opts) do
      {
        shell_id: 'D5A2622B-B842-4EB8-8A78-0225C8A993DF',
        command: 'ipconfig'
      }
    end
    subject { described_class.new(default_connection_opts, cmd_opts) }
    let(:xml) { subject.build }
    it 'creates a well formed message' do
      expect(xml).to include('<w:OperationTimeout>PT60S</w:OperationTimeout>')
    end
  end
end
