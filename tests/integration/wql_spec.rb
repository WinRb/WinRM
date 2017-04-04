# encoding: UTF-8
require_relative 'spec_helper'

describe 'winrm client wql' do
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

  it 'should query Win32_Process' do
    output = @winrm.run_wql('select * from Win32_Process')
    expect(output).to_not be_empty
    process_count = output[:win32_process].count
    expect(process_count).to be > 1
    expect(output[:win32_process]).to all(include(:command_line))
  end

  it 'should query Win32_Process with block' do
    count = 0
    @winrm.run_wql('select * from Win32_Process') do |type, item|
      expect(type).to eq(:win32_process)
      expect(item).to include(:command_line)
      count += 1
    end
    expect(count).to be > 1
  end
end
