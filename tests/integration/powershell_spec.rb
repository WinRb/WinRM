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

  describe 'ipconfig with invalid args' do
    subject(:output) { @powershell.run('ipconfig blah') }
    it { should have_exit_code 1 }
  end

  describe 'throw' do
    subject(:output) { @powershell.run("throw 'an error occured'") }
    it { should have_exit_code 0 }
    it { should have_stderr_match(/an error occured/) }
  end

  describe 'exit' do
    subject(:output) { @powershell.run('exit 5') }
    it { should have_exit_code 5 }
  end

  describe 'echo \'hello world\' using apostrophes' do
    subject(:output) { @powershell.run("echo 'hello world'") }
    it { should have_exit_code 0 }
    it { should have_stdout_match(/hello world/) }
    it { should have_no_stderr }
  end

  describe 'handling special XML characters' do
    subject(:output) { @powershell.run("echo 'hello & <world>'") }
    it { should have_exit_code 0 }
    it { should have_stdout_match(/hello & <world>/) }
    it { should have_no_stderr }
  end

  describe 'dir with incorrect argument /z' do
    subject(:output) { @powershell.run('dir /z') }
    it { should have_stderr_match(/Cannot find path/) }
    it { should have_no_stdout }
  end

  describe 'Math area calculation' do
    subject(:output) do
      @powershell.run <<-EOH
        $diameter = 4.5
        $area = [Math]::pow([Math]::PI * ($diameter/2), 2)
        Write-Host $area
      EOH
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
      expect(output.stdout).to eq("Hello\r\n")
      expect(output.stdout).to eq(@captured_stdout)
    end

    it 'should have stderr' do
      expect(output.stderr).to eq(", world!\r\n")
      expect(output.stderr).to eq(@captured_stderr)
    end

    it 'should have output' do
      expect(output.output).to eq("Hello\r\n, world!\r\n")
    end
  end

  describe 'capturing output from pipeline followed by Host' do
    subject(:output) do
      script = <<-eos
      Write-Output 'output'
      $host.UI.Writeline('host')
      eos

      @captured_stdout = ''
      @captured_stderr = ''
      @powershell.run(script) do |stdout, stderr|
        @captured_stdout << stdout if stdout
        @captured_stderr << stderr if stderr
      end
    end

    it 'should print from the pipeline first' do
      expect(output.stdout).to start_with("output\r\n")
    end

    it 'should write to host last' do
      expect(output.stdout).to end_with("host\r\n")
    end
  end

  describe 'it should handle utf-8 characters' do
    subject(:output) { @powershell.run('echo "✓1234-äöü"') }
    it { should have_exit_code 0 }
    it { should have_stdout_match(/✓1234-äöü/) }
  end

  describe 'output exceeds a single fragment' do
    subject(:output) { @powershell.run('Write-Output $("a"*600000)') }
    it { should have_exit_code 0 }
    it 'has assebled the output' do
      expect(output.stdout).to eq('a' * 600000 + "\r\n")
    end
  end

  describe 'command exceeds a single fragment' do
    subject(:output) { @powershell.run("$var='#{'a' * 600000}';Write-Output 'long var'") }
    it { should have_exit_code 0 }
    it 'has sent the output' do
      expect(output.stdout).to eq("long var\r\n")
    end
  end

  describe 'reading pipeline messages' do
    subject(:messages) { @powershell.send_pipeline_command('ipconfig') }

    it 'returns multiple messages' do
      expect(messages.length).to be > 1
    end
    it 'first message is pipeline output' do
      expect(messages.first.type).to eq(WinRM::PSRP::Message::MESSAGE_TYPES[:pipeline_output])
    end
    it 'last message is pipeline state' do
      expect(messages.last.type).to eq(WinRM::PSRP::Message::MESSAGE_TYPES[:pipeline_state])
    end
  end
end
