# encoding: UTF-8
describe WinRM::PSRP::UUID do
  subject(:uuid_helper) do
    Object.new.extend(WinRM::PSRP::UUID)
  end
  context 'uuid is nil' do
    uuid = nil
    it 'should return an empty byte array' do
      bytes = uuid_helper.uuid_to_windows_guid_bytes(uuid)
      expect(bytes).to eq([0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0])
    end
  end
  context 'uuid 08785e96-eb1b-4a74-a767-7b56e8f13ea9 with lower case letters' do
    uuid = '08785e96-eb1b-4a74-a767-7b56e8f13ea9'
    it 'should return a Windows GUID struct compatible little endian byte array' do
      bytes = uuid_helper.uuid_to_windows_guid_bytes(uuid)
      expect(bytes).to eq([150, 94, 120, 8, 27, 235, 116, 74, 167, 103, 123, 86, 232, 241, 62, 169])
    end
  end
  context 'uuid 045F9E19D-8B77-4394-AB0C-197497661668 with upper case letters' do
    uuid = '45F9E19D-8B77-4394-AB0C-197497661668'
    it 'should return a Windows GUID struct compatible little endian byte array' do
      bytes = uuid_helper.uuid_to_windows_guid_bytes(uuid)
      expect(bytes).to eq(
        [157, 225, 249, 69, 119, 139, 148, 67, 171, 12, 25, 116, 151, 102, 22, 104])
    end
  end
end
