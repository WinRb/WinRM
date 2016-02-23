# encoding: UTF-8

require 'winrm/wsmv/wql_query'

describe 'WqlQuery', unit: true do
  context 'default session options' do
    session_opts = {
      endpoint: 'http://localhost:5985/wsman',
      max_envelope_size: 153600,
      session_id: '05A2622B-B842-4EB8-8A78-0225C8A993DF',
      operation_timeout: 60,
      locale: 'en-US'
    }
    it 'creates a well formed message' do
      xml = WinRM::WSMV::WqlQuery.new(session_opts, 'SELECT * FROM Win32').build
      expect(xml).to include('<w:OperationTimeout>PT60S</w:OperationTimeout>')
    end
  end
end
