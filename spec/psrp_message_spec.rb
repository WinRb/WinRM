# encoding: UTF-8
describe 'PsrpMessage', unit: true do
  context 'all fields provided' do
    subject(:bytes) do
      msg = WinRM::PSRP::Message.new(
        1,
        'bc1bfbba-8215-4a04-b2df-7a3ac0310e16',
        '4218a578-0f18-4b19-82c3-46b433319126',
        0x00010002,
        %{<Obj RefId="0"><MS><I32 N="MinRunspaces">1</I32><I32 N="MaxRunspaces">1</I32><Obj N="PSThreadOptions" RefId="1"><TN RefId="0"><T>System.Management.Automation.Runspaces.PSThreadOptions</T><T>System.Enum</T><T>System.ValueType</T><T>System.Object</T></TN><ToString>Default</ToString><I32>0</I32></Obj><Obj N="ApartmentState" RefId="2"><TN RefId="1"><T>System.Threading.ApartmentState</T><T>System.Enum</T><T>System.ValueType</T><T>System.Object</T></TN><ToString>Unknown</ToString><I32>2</I32></Obj><Obj N="ApplicationArguments" RefId="3"><TN RefId="2"><T>System.Management.Automation.PSPrimitiveDictionary</T><T>System.Collections.Hashtable</T><T>System.Object</T></TN><DCT><En><S N="Key">PSVersionTable</S><Obj N="Value" RefId="4"><TNRef RefId="2" /><DCT><En><S N="Key">PSVersion</S><Version N="Value">5.0.11082.1000</Version></En><En><S N="Key">PSCompatibleVersions</S><Obj N="Value" RefId="5"><TN RefId="3"><T>System.Version[]</T><T>System.Array</T><T>System.Object</T></TN><LST><Version>1.0</Version><Version>2.0</Version><Version>3.0</Version><Version>4.0</Version><Version>5.0.11082.1000</Version></LST></Obj></En><En><S N="Key">CLRVersion</S><Version N="Value">4.0.30319.42000</Version></En><En><S N="Key">BuildVersion</S><Version N="Value">10.0.11082.1000</Version></En><En><S N="Key">WSManStackVersion</S><Version N="Value">3.0</Version></En><En><S N="Key">PSRemotingProtocolVersion</S><Version N="Value">2.3</Version></En><En><S N="Key">SerializationVersion</S><Version N="Value">1.1.0.1</Version></En></DCT></Obj></En></DCT></Obj><Obj N="HostInfo" RefId="6"><MS><Obj N="_hostDefaultData" RefId="7"><MS><Obj N="data" RefId="8"><TN RefId="4"><T>System.Collections.Hashtable</T><T>System.Object</T></TN><DCT><En><I32 N="Key">9</I32><Obj N="Value" RefId="9"><MS><S N="T">System.String</S><S N="V">C:\dev\kitchen-vagrant</S></MS></Obj></En><En><I32 N="Key">8</I32><Obj N="Value" RefId="10"><MS><S N="T">System.Management.Automation.Host.Size</S><Obj N="V" RefId="11"><MS><I32 N="width">199</I32><I32 N="height">52</I32></MS></Obj></MS></Obj></En><En><I32 N="Key">7</I32><Obj N="Value" RefId="12"><MS><S N="T">System.Management.Automation.Host.Size</S><Obj N="V" RefId="13"><MS><I32 N="width">80</I32><I32 N="height">52</I32></MS></Obj></MS></Obj></En><En><I32 N="Key">6</I32><Obj N="Value" RefId="14"><MS><S N="T">System.Management.Automation.Host.Size</S><Obj N="V" RefId="15"><MS><I32 N="width">80</I32><I32 N="height">25</I32></MS></Obj></MS></Obj></En><En><I32 N="Key">5</I32><Obj N="Value" RefId="16"><MS><S N="T">System.Management.Automation.Host.Size</S><Obj N="V" RefId="17"><MS><I32 N="width">80</I32><I32 N="height">9999</I32></MS></Obj></MS></Obj></En><En><I32 N="Key">4</I32><Obj N="Value" RefId="18"><MS><S N="T">System.Int32</S><I32 N="V">25</I32></MS></Obj></En><En><I32 N="Key">3</I32><Obj N="Value" RefId="19"><MS><S N="T">System.Management.Automation.Host.Coordinates</S><Obj N="V" RefId="20"><MS><I32 N="x">0</I32><I32 N="y">9974</I32></MS></Obj></MS></Obj></En><En><I32 N="Key">2</I32><Obj N="Value" RefId="21"><MS><S N="T">System.Management.Automation.Host.Coordinates</S><Obj N="V" RefId="22"><MS><I32 N="x">0</I32><I32 N="y">9998</I32></MS></Obj></MS></Obj></En><En><I32 N="Key">1</I32><Obj N="Value" RefId="23"><MS><S N="T">System.ConsoleColor</S><I32 N="V">0</I32></MS></Obj></En><En><I32 N="Key">0</I32><Obj N="Value" RefId="24"><MS><S N="T">System.ConsoleColor</S><I32 N="V">7</I32></MS></Obj></En></DCT></Obj></MS></Obj><B N="_isHostNull">false</B><B N="_isHostUINull">false</B><B N="_isHostRawUINull">false</B><B N="_useRunspaceHost">false</B></MS></Obj></MS></Obj>})
      msg.bytes
    end
    it 'sets the message id to 1' do
      expect(bytes[0..7]).to eq([0, 0, 0, 0, 0, 0, 0, 1])
    end
    it 'sets the fragment id to 0' do
      expect(bytes[8..15]).to eq([0, 0, 0, 0, 0, 0, 0, 0])
    end
    it 'clears 6 reserved bits' do
      expect(bytes[16] & 0b11111100).to eq(0)
    end
    it 'sets end fragment bit' do
      expect(bytes[16] & 0b00000010).to eq(2)
    end
    it 'sets start fragment bit' do
      expect(bytes[16] & 0b00000001).to eq(1)
    end
    it 'sets message blob length to 3640' do
      expect(bytes[17..20]).to eq([0, 0, 14, 56])
    end
    it 'sets the destination to server LE' do
      expect(bytes[21..24]).to eq([2, 0, 0, 0])
    end
    it 'sets the message type LE' do
      expect(bytes[25..28]).to eq([2, 0, 1, 0])
    end
    it 'sets the runspace pool id' do
      expect(bytes[29..44]).to eq([186, 251, 27, 188, 21, 130, 4, 74, 178, 223, 122, 58, 192, 49, 14, 22])
    end
    it 'sets the pipeline id' do
      expect(bytes[45..60]).to eq([120, 165, 24, 66, 24, 15, 25, 75, 130, 195, 70, 180, 51, 49, 145, 38])
    end
    it 'prefixes the blob with BOM' do
      expect(bytes[61..63]).to eq([239, 187, 191])
    end
    it 'contains at least the first 8 bytes of the XML payload' do
      expect(bytes[64..71]).to eq([60, 79, 98, 106, 32, 82, 101, 102])
    end
  end
  context 'create' do
    it 'raises error when shell id is nil' do
      expect do
        WinRM::PSRP::Message.new(
          1,
          nil,
          '4218a578-0f18-4b19-82c3-46b433319126',
          0x00010002,
          %{<Obj RefId="0"/>})
      end.to raise_error(RuntimeError)
    end
    it 'raises error when message type is not valid' do
      expect do
        WinRM::PSRP::Message.new(
          1,
          'bc1bfbba-8215-4a04-b2df-7a3ac0310e16',
          '4218a578-0f18-4b19-82c3-46b433319126',
          0x00000000,
          %{<Obj RefId="0"/>})
      end.to raise_error(RuntimeError)
    end
    it 'raises error when payload is nil' do
      expect do
        WinRM::PSRP::Message.new(
          1,
          'bc1bfbba-8215-4a04-b2df-7a3ac0310e16',
          '4218a578-0f18-4b19-82c3-46b433319126',
          0x00010002,
          nil)
      end.to raise_error(RuntimeError)
    end
  end
  context 'no command id' do
    subject(:msg) do
      WinRM::PSRP::Message.new(
        1,
        'bc1bfbba-8215-4a04-b2df-7a3ac0310e16',
        nil,
        0x00010002,
        %{<Obj RefId="0"><MS><Version N="protocolversion">2.3</Version><Version N="PSVersion">2.0</Version><Version N="SerializationVersion">1.1.0.1</Version></MS></Obj>})
    end
    it 'does not error' do
      expect{msg.bytes}.to_not raise_error
    end
    it 'sets the pipeline id to empty' do
      expect(msg.bytes[45..60]).to eq([0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0])
    end
  end
end
