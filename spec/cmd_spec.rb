describe 'winrm client cmd', :integration => true do
  before(:all) do
    @winrm = winrm_connection
  end

  describe 'empty string' do
    subject(:output) { @winrm.cmd('') }
    it { should have_exit_code 0 }
    it { should have_no_stdout }
    it { should have_no_stderr }
  end

  describe 'ipconfig' do
    subject(:output) { @winrm.cmd('ipconfig') }
    it { should have_exit_code 0 }
    it { should have_stdout_match /Windows IP Configuration/ }
    it { should have_no_stderr }
  end

  describe 'echo \'hello world\' using apostrophes' do
    subject(:output) { @winrm.cmd("echo 'hello world'") }
    it { should have_exit_code 0 }
    it { should have_stdout_match /'hello world'/ }
    it { should have_no_stderr }
  end

  describe 'ipconfig with /all argument' do
    subject(:output) { @winrm.cmd('ipconfig', %w{/all}) }
    it { should have_exit_code 0 }
    it { should have_stdout_match /Windows IP Configuration/ }
    it { should have_no_stderr }
  end

  describe 'dir with incorrect argument /z' do
    subject(:output) { @winrm.cmd('dir /z') }
    it { should have_exit_code 1 }
    it { should have_no_stdout }
    it { should have_stderr_match /Invalid switch/ }
  end

  describe 'ipconfig && echo error 1>&2' do
    subject(:output) { @winrm.cmd('ipconfig && echo error 1>&2') }
    it { should have_exit_code 0 }
    it { should have_stdout_match /Windows IP Configuration/ }
    it { should have_stderr_match /error/ }
  end

  describe 'ipconfig with a block' do
    subject(:stdout) do
      outvar = ''
      @winrm.cmd('ipconfig') do |stdout, stderr|
        outvar << stdout
      end
      outvar
    end
    it { should match(/Windows IP Configuration/) }
  end
end
