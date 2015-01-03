# encoding: UTF-8
describe 'winrm client wql', integration: true do
  before(:all) do
    @winrm = winrm_connection
  end

  it 'should query Win32_OperatingSystem' do
    output = @winrm.run_wql('select * from Win32_OperatingSystem')
    expect(output).to_not be_empty
    output_caption = output[:win32_operating_system][0][:caption]
    expect(output_caption).to include('Microsoft')
    expect(output_caption).to include('Windows')
  end
end
