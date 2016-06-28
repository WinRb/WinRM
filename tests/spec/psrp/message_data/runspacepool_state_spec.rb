# encoding: UTF-8

require 'winrm/psrp/message_data/base'
require 'winrm/psrp/message_data/runspacepool_state'

describe WinRM::PSRP::MessageData::RunspacepoolState do
  let(:raw_data) do
    "\xEF\xBB\xBF<Obj RefId=\"0\"><MS><I32 N=\"RunspaceState\">2</I32></MS></Obj>"
  end

  subject { described_class.new(raw_data) }

  it 'parses runspace state' do
    expect(subject.runspace_state).to eq(WinRM::PSRP::MessageData::RunspacepoolState::OPENED)
  end
end
