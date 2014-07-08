describe "Test remote WQL features via WinRM", :integration => true do
  before(:all) do
    @winrm = winrm_connection
  end

  it 'should run a CMD command string' do
    output = @winrm.run_cmd('ipconfig /all')
    expect(output[:exitcode]).to eq(0)
    expect(output[:data]).to_not be_empty
  end

  it 'should run a CMD command with proper arguments' do
    output = @winrm.run_cmd('ipconfig', %w{/all})
    expect(output[:exitcode]).to eq(0)
    expect(output[:data]).to_not be_empty
  end

  it 'should run a CMD command with block' do
    outvar = ''
    @winrm.run_cmd('ipconfig', %w{/all}) do |stdout, stderr|
      outvar << stdout
    end
    expect(outvar).to match(/Windows IP Configuration/)
  end

  it 'should run a CMD command that contains an apostrophe' do
    output = @winrm.run_cmd(%q{echo 'hello world'})
    expect(output[:exitcode]).to eq(0)
    expect(output[:data][0][:stdout]).to match(/'hello world'/)
  end

  it 'should run a CMD command that is empty' do
    output = @winrm.run_cmd('')
    expect(output[:exitcode]).to eq(0)
  end
end
