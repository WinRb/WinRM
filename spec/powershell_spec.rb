describe 'winrm client powershell', :integration => true do
  before(:all) do
    @winrm = winrm_connection
  end

  describe 'empty string' do
    subject(:output) { @winrm.powershell('') }
    it { should have_exit_code 4294770688 }
    it { should have_stderr_match /Cannot process the command because of a missing parameter/ }
  end

  describe 'ipconfig' do
    subject(:output) { @winrm.powershell('ipconfig') }
    it { should have_exit_code 0 }
    it { should have_stdout_match /Windows IP Configuration/ }
    it { should have_no_stderr }
  end

  describe 'echo \'hello world\' using apostrophes' do
    subject(:output) { @winrm.powershell("echo 'hello world'") }
    it { should have_exit_code 0 }
    it { should have_stdout_match /hello world/ }
    it { should have_no_stderr }
  end

  describe 'dir with incorrect argument /z' do
    subject(:output) { @winrm.powershell('dir /z') }
    it { should have_exit_code 1 }
    it { should have_no_stdout }
    #TODO Better 
    #it { should have_stderr_match /Invalid switch/ }
  end

  describe 'Math area calculation' do
    subject(:output) do
      @winrm.powershell(<<-EOH
        $diameter = 4.5
        $area = [Math]::pow([Math]::PI * ($diameter/2), 2)
        Write-Host $area
      EOH
      )
    end
    it { should have_exit_code 0 }
    it { should have_stdout_match /49.9648722805149/ }
    it { should have_no_stderr }
  end

  describe 'ipconfig with a block' do
    subject(:stdout) do
      outvar = ''
      @winrm.powershell('ipconfig') do |stdout, stderr|
        outvar << stdout
      end
      outvar
    end
    it { should match(/Windows IP Configuration/) }
  end
end


