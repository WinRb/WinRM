# encoding: UTF-8

require 'winrm/psrp/message_data/base'
require 'winrm/psrp/message_data/runspacepool_host_call'

describe WinRM::PSRP::MessageData::RunspacepoolHostCall do
  let(:raw_data) do
    "\xEF\xBB\xBF<Obj RefId=\"0\"><MS><I64 N=\"ci\">-100</I64><Obj N=\"mi\" RefId=\"1\">"\
    '<TN RefId="0"><T>System.Management.Automation.Remoting.RemoteHostMethodId</T>'\
    '<T>System.Enum</T><T>System.ValueType</T><T>System.Object</T></TN>'\
    '<ToString>WriteLine3</ToString><I32>17</I32></Obj><Obj N="mp" RefId="2">'\
    '<TN RefId="1"><T>System.Collections.ArrayList</T><T>System.Object</T></TN><LST>'\
    '<I32>7</I32><I32>0</I32><S>hello</S></LST></Obj></MS></Obj>'
  end

  subject { described_class.new(raw_data) }

  it 'parses method identifier' do
    expect(subject.method_identifier).to eq('WriteLine3')
  end

  it 'parses method parameters' do
    expect(subject.method_parameters[:s]).to eq('hello')
  end
end
