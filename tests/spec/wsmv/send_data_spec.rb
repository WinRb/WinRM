# encoding: UTF-8

require 'winrm/wsmv/send_data'

describe WinRM::WSMV::SendData do
  context 'default session options' do
    let(:shell_id) { 'D5A2622B-B842-4EB8-8A78-0225C8A993DF' }
    let(:command_id) { 'D5A2622B-B842-4EB8-8A78-0225C8A993DF' }
    let(:fragment) { WinRM::PSRP::Fragment.new(1, [1, 2, 3]) }
    let(:pipeline) { Base64.strict_encode64(fragment.bytes.pack('C*')) }

    subject do
      described_class.new(
        default_connection_opts,
        shell_id,
        command_id,
        fragment
      )
    end
    let(:xml) { subject.build }
    it 'creates a well formed message' do
      expect(xml).to include('<w:OperationTimeout>PT60S</w:OperationTimeout>')
      expect(xml).to include(
        '<w:SelectorSet><w:Selector Name="ShellId">' \
        "#{shell_id}</w:Selector></w:SelectorSet>")
      expect(xml).to include(
        "<rsp:Stream Name=\"stdin\" CommandId=\"#{command_id}\">#{pipeline}</rsp:Stream>")
    end
  end
end
