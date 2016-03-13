# encoding: UTF-8
require_relative 'spec_helper'

describe 'winrm client powershell' do
  before(:all) do
    @powershell = winrm_connection.shell(:powershell)
  end

  describe 'ipconfig' do
    subject(:output) { @powershell.run('ipconfig') }
    it { should have_exit_code 0 }
    it { should have_stdout_match(/Windows IP Configuration/) }
    it { should have_no_stderr }
  end

  describe 'echo \'hello world\' using apostrophes' do
    subject(:output) { @powershell.run("echo 'hello world'") }
    it { should have_exit_code 0 }
    it { should have_stdout_match(/hello world/) }
    it { should have_no_stderr }
  end

  describe 'dir with incorrect argument /z' do
    subject(:output) { @powershell.run('dir /z') }
    it { should have_stderr_match(/Cannot find path/) }
    it { should have_no_stdout }
  end

  describe 'Math area calculation' do
    subject(:output) do
      @powershell.run(<<-EOH
        $diameter = 4.5
        $area = [Math]::pow([Math]::PI * ($diameter/2), 2)
        Write-Host $area
      EOH
      )
    end
    it { should have_exit_code 0 }
    it { should have_stdout_match(/49.9648722805149/) }
    it { should have_no_stderr }
  end

  describe 'ipconfig with a block' do
    subject(:stdout) do
      outvar = ''
      @powershell.run('ipconfig') do |stdout, _stderr|
        outvar << stdout
      end
      outvar
    end
    it { should match(/Windows IP Configuration/) }
  end

  describe 'capturing output from Write-Host and Write-Error' do
    subject(:output) do
      script = <<-eos
      Write-Host 'Hello'
      $host.ui.WriteErrorLine(', world!')
      eos

      @captured_stdout = ''
      @captured_stderr = ''
      @powershell.run(script) do |stdout, stderr|
        @captured_stdout << stdout if stdout
        @captured_stderr << stderr if stderr
      end
    end

    it 'should have stdout' do
      expect(output.stdout).to eq("Hello")
      expect(output.stdout).to eq(@captured_stdout)
    end

    it 'should have stderr' do
      expect(output.stderr).to eq(', world!')
      expect(output.stderr).to eq(@captured_stderr)
    end

    it 'should have output' do
      expect(output.output).to eq('Hello, world!')
    end
  end

  describe 'it should handle utf-8 characters' do
    subject(:output) { @powershell.run('echo "✓1234-äöü"') }
    it { should have_exit_code 0 }
    it { should have_stdout_match(/✓1234-äöü/) }
  end
end
