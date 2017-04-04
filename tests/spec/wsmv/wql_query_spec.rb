# encoding: UTF-8

require 'winrm/wsmv/wql_query'

describe WinRM::WSMV::WqlQuery do
  context 'default session options' do
    subject { described_class.new(nil, default_connection_opts, 'SELECT * FROM Win32') }
    let(:xml) { subject.build }
    it 'creates a well formed message' do
      expect(xml).to include('<w:OperationTimeout>PT60S</w:OperationTimeout>')
    end
  end
end
