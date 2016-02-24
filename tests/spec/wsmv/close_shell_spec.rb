# encoding: UTF-8

require 'winrm/wsmv/close_shell'

describe WinRM::WSMV::CloseShell do
  context 'default session options' do
    subject do
      described_class.new(default_connection_opts, shell_id: 'F4A2622B-B842-4EB8-8A78-0225C8A993DF')
    end
    let(:xml) { subject.build }
    it 'creates a well formed message' do
      expect(xml).to include('<w:OperationTimeout>PT60S</w:OperationTimeout>')
      expect(xml).to include('<a:Action mustUnderstand="true">' \
        'http://schemas.xmlsoap.org/ws/2004/09/transfer/Delete</a:Action>')
    end
  end
end
