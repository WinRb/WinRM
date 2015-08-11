# encoding: UTF-8
describe 'winrm client cmd', integration: true do
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
    it { should have_stdout_match(/Windows IP Configuration/) }
    it { should have_no_stderr }
  end

  describe 'echo \'hello world\' using apostrophes' do
    subject(:output) { @winrm.cmd("echo 'hello world'") }
    it { should have_exit_code 0 }
    it { should have_stdout_match(/'hello world'/) }
    it { should have_no_stderr }
  end

  describe 'echo "string with trailing \\" using double quotes' do
    # This is a regression test for #131.  " is converted to &quot; when serializing
    # the command to SOAP/XML.  Any naive substitution performed on such a serialized
    # string can result in any \& sequence being interpreted as a back-substitution.
    subject(:output) { @winrm.cmd('echo "string with trailing \\"') }
    it { should have_exit_code 0 }
    it { should have_stdout_match(/string with trailing \\/) }
    it { should have_no_stderr }
  end

  describe 'capturing output from stdout and stderr' do
    subject(:output) do
      # Note: Multiple lines doesn't work:
      # script = <<-eos
      # echo Hello
      # echo , world! 1>&2
      # eos

      script = 'echo Hello & echo , world! 1>&2'

      @captured_stdout = ''
      @captured_stderr = ''
      @winrm.cmd(script) do |stdout, stderr|
        @captured_stdout << stdout if stdout
        @captured_stderr << stderr if stderr
      end
    end

    it 'should have stdout' do
      expect(output.stdout).to eq("Hello \r\n")
      expect(output.stdout).to eq(@captured_stdout)
    end

    it 'should have stderr' do
      expect(output.stderr).to eq(", world! \r\n")
      expect(output.stderr).to eq(@captured_stderr)
    end

    it 'should have output' do
      expect(output.output).to eq("Hello \r\n, world! \r\n")
    end
  end

  describe 'ipconfig with /all argument' do
    subject(:output) { @winrm.cmd('ipconfig', %w(/all)) }
    it { should have_exit_code 0 }
    it { should have_stdout_match(/Windows IP Configuration/) }
    it { should have_no_stderr }
  end

  describe 'dir with incorrect argument /z' do
    subject(:output) { @winrm.cmd('dir /z') }
    it { should have_exit_code 1 }
    it { should have_no_stdout }
    it { should have_stderr_match(/Invalid switch/) }
  end

  describe 'ipconfig && echo error 1>&2' do
    subject(:output) { @winrm.cmd('ipconfig && echo error 1>&2') }
    it { should have_exit_code 0 }
    it { should have_stdout_match(/Windows IP Configuration/) }
    it { should have_stderr_match(/error/) }
  end

  describe 'ipconfig with a block' do
    subject(:stdout) do
      outvar = ''
      @winrm.cmd('ipconfig') do |stdout, _stderr|
        outvar << stdout
      end
      outvar
    end
    it { should match(/Windows IP Configuration/) }
  end
end
