# encoding: UTF-8
require_relative 'spec_helper'

describe 'winrm client cmd' do
  before(:all) do
    @cmd_shell = winrm_connection.shell(:cmd)
  end

  describe 'empty string' do
    subject(:output) { @cmd_shell.run('') }
    it { should have_exit_code 0 }
    it { should have_no_stdout }
    it { should have_no_stderr }
  end

  describe 'ipconfig' do
    subject(:output) { @cmd_shell.run('ipconfig') }
    it { should have_exit_code 0 }
    it { should have_stdout_match(/Windows IP Configuration/) }
    it { should have_no_stderr }
  end

  describe 'codepage' do
    let(:options) { Hash.new }
    let(:shell) { winrm_connection.shell(:cmd, options) }

    after { shell.close }

    subject(:output) { shell.run('chcp') }

    it 'should default to UTF-8 (65001)' do
      should have_stdout_match(/Active code page: 65001/)
    end

    context 'when changing the codepage' do
      let(:options) { { codepage: 437 } }

      it 'sets the codepage to the one given' do
        should have_stdout_match(/Active code page: 437/)
      end
    end
  end

  describe 'echo \'hello world\' using apostrophes' do
    subject(:output) { @cmd_shell.run("echo 'hello world'") }
    it { should have_exit_code 0 }
    it { should have_stdout_match(/'hello world'/) }
    it { should have_no_stderr }
  end

  describe 'multi stream output from large file' do
    subject(:output) { @cmd_shell.run('type c:\windows\logs\dism\dism.log') }
    it { should have_exit_code 0 }
    it { should have_no_stderr }
  end

  describe 'echo "string with trailing \\" using double quotes' do
    # This is a regression test for #131.  " is converted to &quot; when serializing
    # the command to SOAP/XML.  Any naive substitution performed on such a serialized
    # string can result in any \& sequence being interpreted as a back-substitution.
    subject(:output) { @cmd_shell.run('echo "string with trailing \\"') }
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
      @cmd_shell.run(script) do |stdout, stderr|
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
    subject(:output) { @cmd_shell.run('ipconfig', %w(/all)) }
    it { should have_exit_code 0 }
    it { should have_stdout_match(/Windows IP Configuration/) }
    it { should have_no_stderr }
  end

  describe 'dir with incorrect argument /z' do
    subject(:output) { @cmd_shell.run('dir /z') }
    it { should have_exit_code 1 }
    it { should have_no_stdout }
    it { should have_stderr_match(/Invalid switch/) }
  end

  describe 'ipconfig && echo error 1>&2' do
    subject(:output) { @cmd_shell.run('ipconfig && echo error 1>&2') }
    it { should have_exit_code 0 }
    it { should have_stdout_match(/Windows IP Configuration/) }
    it { should have_stderr_match(/error/) }
  end

  describe 'ipconfig with a block' do
    subject(:stdout) do
      outvar = ''
      @cmd_shell.run('ipconfig') do |stdout, _stderr|
        outvar << stdout
      end
      outvar
    end
    it { should match(/Windows IP Configuration/) }
  end
end
