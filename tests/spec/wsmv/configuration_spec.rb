# encoding: UTF-8

require 'winrm/wsmv/configuration'

describe WinRM::WSMV::Configuration do
  subject do
    described_class.new(default_connection_opts)
  end
  let(:xml) { subject.build }
  it 'creates a well formed message' do
    expect(xml).to include('<w:OperationTimeout>PT60S</w:OperationTimeout>')
    expect(xml).to include('<a:Action mustUnderstand="true">' \
      'http://schemas.xmlsoap.org/ws/2004/09/transfer/Get</a:Action>')
    expect(xml).to include('w:ResourceURI mustUnderstand="true">' \
      'http://schemas.microsoft.com/wbem/wsman/1/config</w:ResourceURI>')
  end
end
