# -*- encoding: utf-8 -*-
#
# Author:: Fletcher (<fnichol@nichol.ca>)
#
# Copyright (C) 2015, Fletcher Nichol
#
# Licensed under the Apache License, Version 2.0 (the 'License');
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an 'AS IS' BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

require 'winrm/command_executor'

require 'base64'
require 'securerandom'

describe WinRM::CommandExecutor, unit: true do
  let(:logged_output)   { StringIO.new }
  let(:shell_id)        { 'shell-123' }
  let(:executor_args)   { [service, logger] }
  let(:executor) { WinRM::CommandExecutor.new(service) }
  let(:service) do
    double(
      'winrm_service',
      logger: Logging.logger['test'],
      retry_limit: 1,
      retry_delay: 1
    )
  end

  let(:version_output) { { xml_fragment: [{ version: '6.3.9600' }] } }

  before do
    allow(service).to receive(:open_shell).and_return(shell_id)
    allow(service).to receive(:run_wql).and_return(version_output)
  end

  describe '#close' do
    it 'calls service#close_shell' do
      executor.open
      expect(service).to receive(:close_shell).with(shell_id)

      executor.close
    end

    it 'only calls service#close_shell once for multiple calls' do
      executor.open
      expect(service).to receive(:close_shell).with(shell_id).once

      executor.close
      executor.close
      executor.close
    end

    it 'undefines finalizer' do
      allow(service).to receive(:close_shell)
      allow(ObjectSpace).to receive(:define_finalizer) { |e, _| e == executor }
      expect(ObjectSpace).to receive(:undefine_finalizer).with(executor)
      executor.open

      executor.close
    end
  end

  describe '#open' do
    it 'calls service#open_shell' do
      expect(service).to receive(:open_shell).and_return(shell_id)

      executor.open
    end

    it 'defines a finalizer' do
      expect(ObjectSpace).to receive(:define_finalizer) do |e, _|
        expect(e).to eq(executor)
      end

      executor.open
    end

    it 'returns a shell id as a string' do
      expect(executor.open).to eq shell_id
    end

    describe 'failed connection attempts' do
      let(:error) { HTTPClient::ConnectTimeoutError }
      let(:limit) { 3 }
      let(:delay) { 0.1 }

      before do
        allow(service).to receive(:open_shell).and_raise(error)
        allow(service).to receive(:retry_delay).and_return(delay)
        allow(service).to receive(:retry_limit).and_return(limit)
      end

      it 'attempts to connect :retry_limit times' do
        begin
          allow(service).to receive(:open_shell).exactly.times(limit)
          executor.open
        rescue # rubocop:disable Lint/HandleExceptions
          # the raise is not what is being tested here, rather its side-effect
        end
      end

      it 'raises the inner error after retries' do
        expect { executor.open }.to raise_error(error)
      end
    end

    describe 'for modern windows distributions' do
      let(:version_output) { { xml_fragment: [{ version: '10.0.10586.63' }] } }

      it 'sets #max_commands to 1500 - 2' do
        expect(executor.max_commands).to eq(1500 - 2)
      end

      it 'sets code_page to UTF-8' do
        expect(executor.code_page).to eq 65_001
      end
    end

    describe 'for older/legacy windows distributions' do
      let(:version_output) { { xml_fragment: [{ version: '6.1.8500' }] } }

      it 'sets #max_commands to 15 - 2' do
        expect(executor.max_commands).to eq(15 - 2)
      end

      it 'sets code_page to UTF-8' do
        expect(executor.code_page).to eq 65_001
      end
    end

    describe 'for super duper older/legacy windows distributions' do
      let(:version_output) { { xml_fragment: [{ version: '6.0.8500' }] } }

      it 'sets #max_commands to 15 - 2' do
        expect(executor.max_commands).to eq(15 - 2)
      end

      it 'sets code_page to MS-DOS' do
        expect(executor.code_page).to eq 437
      end
    end

    describe 'when unable to find os version' do
      let(:version_output) { { xml_fragment: [{ funny_clowns: 'haha' }] } }

      it 'raises WinRMError' do
        expect { executor.code_page }.to raise_error(
          ::WinRM::WinRMError,
          'Unable to determine endpoint os version'
        )
      end
    end
  end

  describe '#run_cmd' do
    describe 'when #open has not been previously called' do
      it 'raises a WinRMError error' do
        expect { executor.run_cmd('nope') }.to raise_error(
          ::WinRM::WinRMError,
          "#{executor.class}#open must be called before any run methods are invoked"
        )
      end
    end

    describe 'when #open has been previously called' do
      let(:command_id) { 'command-123' }

      let(:echo_output) do
        o = ::WinRM::Output.new
        o[:exitcode] = 0
        o[:data].concat([
          { stdout: 'Hello\r\n' },
          { stderr: 'Psst\r\n' }
        ])
        o
      end

      before do
        stub_cmd(shell_id, 'echo', ['Hello'], echo_output, command_id)

        executor.open
      end

      it 'calls service#run_command' do
        expect(service).to receive(:run_command).with(shell_id, 'echo', ['Hello'])

        executor.run_cmd('echo', ['Hello'])
      end

      it 'calls service#get_command_output to get results' do
        expect(service).to receive(:get_command_output).with(shell_id, command_id)

        executor.run_cmd('echo', ['Hello'])
      end

      it 'calls service#get_command_output with a block to get results' do
        blk = proc { |_, _| 'something' }
        expect(service).to receive(:get_command_output).with(shell_id, command_id, &blk)

        executor.run_cmd('echo', ['Hello'], &blk)
      end

      it 'returns an Output object hash' do
        expect(executor.run_cmd('echo', ['Hello'])).to eq echo_output
      end

      it 'runs the block  in #get_command_output when given' do
        io_out = StringIO.new
        io_err = StringIO.new
        stub_cmd(
          shell_id,
          'echo',
          ['Hello'],
          echo_output,
          command_id
        ).and_yield(echo_output.stdout, echo_output.stderr)
        output = executor.run_cmd('echo', ['Hello']) do |stdout, stderr|
          io_out << stdout if stdout
          io_err << stderr if stderr
        end

        expect(io_out.string).to eq 'Hello\r\n'
        expect(io_err.string).to eq 'Psst\r\n'
        expect(output).to eq echo_output
      end

      shared_examples 'retry shell command' do
        it 'does not close the current shell' do
          expect(service).not_to receive(:close_shell)

          executor.run_cmd('echo', ['Hello'])
        end

        it 'opens a new shell once' do
          expect(service).to receive(:open_shell).once

          executor.run_cmd('echo', ['Hello'])
        end

        it 'retries the command once' do
          expect(service).to receive(:run_command).exactly(2).times

          executor.run_cmd('echo', ['Hello'])
        end
      end

      describe 'when shell is closed on server' do
        before do
          @times_called = 0

          allow(service).to receive(:run_command) do
            @times_called += 1
            fail WinRM::WinRMWSManFault.new('oops', '2150858843') if @times_called == 1
          end
        end

        include_examples 'retry shell command'
      end

      describe 'when shell accesses a deleted registry key' do
        before do
          @times_called = 0

          allow(service).to receive(:run_command) do
            @times_called += 1
            fail WinRM::WinRMWSManFault.new('oops', '2147943418') if @times_called == 1
          end
        end

        include_examples 'retry shell command'
      end
    end

    describe 'when called many times over time' do
      # use a 'old' version of windows with lower max_commands threshold
      # to trigger quicker shell recyles
      let(:version_output) { { xml_fragment: [{ version: '6.1.8500' }] } }

      let(:echo_output) do
        o = ::WinRM::Output.new
        o[:exitcode] = 0
        o[:data].concat([{ stdout: 'Hello\r\n' }])
        o
      end

      before do
        allow(service).to receive(:open_shell).and_return('s1', 's2')
        allow(service).to receive(:close_shell)
        allow(service).to receive(:run_command).and_yield('command-xxx')
        allow(service).to receive(:get_command_output).and_return(echo_output)
        allow(service).to receive(:run_wql).with('select version from Win32_OperatingSystem')
          .and_return(version_output)
      end

      it 'resets the shell when #max_commands threshold is tripped' do
        iterations = 35
        reset_times = iterations / (15 - 2)

        expect(service).to receive(:close_shell).exactly(reset_times).times
        executor.open
        iterations.times { executor.run_cmd('echo', ['Hello']) }
      end
    end
  end

  describe '#run_powershell_script' do
    describe 'when #open has not been previously called' do
      it 'raises a WinRMError error' do
        expect { executor.run_powershell_script('nope') }.to raise_error(
          ::WinRM::WinRMError,
          "#{executor.class}#open must be called before any run methods are invoked"
        )
      end
    end

    describe 'when #open has been previously called' do
      let(:command_id) { 'command-123' }

      let(:echo_output) do
        o = ::WinRM::Output.new
        o[:exitcode] = 0
        o[:data].concat([
          { stdout: 'Hello\r\n' },
          { stderr: 'Psst\r\n' }
        ])
        o
      end

      before do
        stub_powershell_script(
          shell_id,
          'echo Hello',
          echo_output,
          command_id
        )

        executor.open
      end

      it 'calls service#run_command' do
        expect(service).to receive(:run_command).with(
          shell_id,
          'powershell',
          [
            '-encodedCommand',
            ::WinRM::PowershellScript.new('echo Hello')
              .encoded
          ]
        )

        executor.run_powershell_script('echo Hello')
      end

      it 'calls service#get_command_output to get results' do
        expect(service).to receive(:get_command_output).with(shell_id, command_id)

        executor.run_powershell_script('echo Hello')
      end

      it 'calls service#get_command_output with a block to get results' do
        blk = proc { |_, _| 'something' }
        expect(service).to receive(:get_command_output).with(shell_id, command_id, &blk)

        executor.run_powershell_script('echo Hello', &blk)
      end

      it 'returns an Output object hash' do
        expect(executor.run_powershell_script('echo Hello')).to eq echo_output
      end

      it 'runs the block  in #get_command_output when given' do
        io_out = StringIO.new
        io_err = StringIO.new
        stub_cmd(shell_id, 'echo', ['Hello'], echo_output, command_id)
          .and_yield(echo_output.stdout, echo_output.stderr)
        output = executor.run_powershell_script('echo Hello') do |stdout, stderr|
          io_out << stdout if stdout
          io_err << stderr if stderr
        end

        expect(io_out.string).to eq 'Hello\r\n'
        expect(io_err.string).to eq 'Psst\r\n'
        expect(output).to eq echo_output
      end
    end

    describe 'when called many times over time' do
      # use a 'old' version of windows with lower max_commands threshold
      # to trigger quicker shell recyles
      let(:version_output) { { xml_fragment: [{ version: '6.1.8500' }] } }

      let(:echo_output) do
        o = ::WinRM::Output.new
        o[:exitcode] = 0
        o[:data].concat([{ stdout: 'Hello\r\n' }])
        o
      end

      before do
        allow(service).to receive(:open_shell).and_return('s1', 's2')
        allow(service).to receive(:close_shell)
        allow(service).to receive(:run_command).and_yield('command-xxx')
        allow(service).to receive(:get_command_output).and_return(echo_output)
        allow(service).to receive(:wsman_identify).with('select version from Win32_OperatingSystem')
          .and_return(version_output)
      end

      it 'resets the shell when #max_commands threshold is tripped' do
        iterations = 35
        reset_times = iterations / (15 - 2)

        expect(service).to receive(:close_shell).exactly(reset_times).times
        executor.open
        iterations.times { executor.run_powershell_script('echo Hello') }
      end
    end
  end

  describe '#shell' do
    it 'is initially nil' do
      expect(executor.shell).to eq nil
    end

    it 'is set after #open is called' do
      executor.open

      expect(executor.shell).to eq shell_id
    end
  end

  def decode(powershell)
    Base64.strict_decode64(powershell).encode('UTF-8', 'UTF-16LE')
  end

  def debug_line_with(msg)
    /^D, .* : #{Regexp.escape(msg)}/
  end

  def regexify(string)
    Regexp.new(Regexp.escape(string))
  end

  def regexify_line(string)
    Regexp.new("^#{Regexp.escape(string)}$")
  end

  # rubocop:disable Metrics/ParameterLists
  def stub_cmd(shell_id, cmd, args, output, command_id = nil, &block)
    command_id ||= SecureRandom.uuid

    allow(service).to receive(:run_command).with(shell_id, cmd, args).and_yield(command_id)
    allow(service).to receive(:get_command_output).with(shell_id, command_id, &block)
      .and_return(output)
  end

  def stub_powershell_script(shell_id, script, output, command_id = nil)
    stub_cmd(
      shell_id,
      'powershell',
      ['-encodedCommand', ::WinRM::PowershellScript.new(script).encoded],
      output,
      command_id
    )
  end
  # rubocop:enable Metrics/ParameterLists
end
