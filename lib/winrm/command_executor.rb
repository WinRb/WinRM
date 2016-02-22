# -*- encoding: utf-8 -*-
#
# Copyright 2015 Shawn Neal <sneal@sneal.net>
# Copyright 2015 Matt Wrock <matt@mattwrock.com>
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

module WinRM
  # Object which can execute multiple commands and Powershell scripts in
  # one shared remote shell session. The maximum number of commands per
  # shell is determined by interrogating the remote host when the session
  # is opened and the remote shell is automatically recycled before the
  # threshold is reached.
  #
  # @author Shawn Neal <sneal@sneal.net>
  # @author Matt Wrock <matt@mattwrock.com>
  # @author Fletcher Nichol <fnichol@nichol.ca>
  class CommandExecutor
    # Closes an open remote shell session left open
    # after a command executor is garbage collecyted.
    #
    # @param shell_id [String] the remote shell identifier
    # @param service [WinRM::WinRMWebService] a winrm web service object
    def self.finalize(shell_id, service)
      proc { service.close_shell(shell_id) }
    end

    # @return [WinRM::WinRMWebService] a WinRM web service object
    attr_reader :service

    # @return [String,nil] the identifier for the current open remote
    #   shell session, or `nil` if the session is not open
    attr_reader :shell

    # Creates a CommandExecutor given a `WinRM::WinRMWebService` object.
    #
    # @param service [WinRM::WinRMWebService] a winrm web service object
    #   responds to `#debug` and `#info` (default: `nil`)
    def initialize(service)
      @service = service
      @command_count = 0
    end

    # Closes the open remote shell session. This method can be called
    # multiple times, even if there is no open session.
    def close
      return if shell.nil?

      service.close_shell(shell)
      remove_finalizer
      @shell = nil
    end

    # Opens a remote shell session for reuse. The maxiumum
    # command-per-shell threshold is also determined the first time this
    # method is invoked and cached for later invocations.
    #
    # @return [String] the remote shell session indentifier
    def open
      close
      retryable(service.retry_limit, service.retry_delay) do
        @shell = service.open_shell(codepage: code_page)
      end
      add_finalizer(shell)
      @command_count = 0
      shell
    end

    # Runs a CMD command.
    #
    # @param command [String] the command to run on the remote system
    # @param arguments [Array<String>] arguments to the command
    # @yield [stdout, stderr] yields more live access the standard
    #   output and standard error streams as they are returns, if
    #   streaming behavior is desired
    # @return [WinRM::Output] output object with stdout, stderr, and
    #   exit code
    def run_cmd(command, arguments = [], &block)
      tries ||= 2

      reset if command_count > max_commands
      ensure_open_shell!

      @command_count += 1
      result = nil
      service.run_command(shell, command, arguments) do |command_id|
        result = service.get_command_output(shell, command_id, &block)
      end
      result
    rescue WinRMWSManFault => e
      # Fault code 2150858843 may be raised if the shell id that the command is sent on
      # has been closed. One might see this on a target windows machine that has just
      # been provisioned and restarted the winrm service at the end of its provisioning
      # routine. If this hapens, we should give the command one more try.

      # Fault code 2147943418 may be raised if the shell is installing an msi and for
      # some reason it tries to read a registry key that has been deleted. This sometimes
      # happens for 2008r2 when installing the Chef omnibus msi.
      if %w(2150858843 2147943418).include?(e.fault_code) && (tries -= 1) > 0
        service.logger.debug('[WinRM] opening new shell since the current one failed')
        @shell = nil
        open
        retry
      else
        raise
      end
    end

    # Run a Powershell script that resides on the local box.
    #
    # @param script_file [IO,String] an IO reference for reading the
    #   Powershell script or the actual file contents
    # @yield [stdout, stderr] yields more live access the standard
    #   output and standard error streams as they are returns, if
    #   streaming behavior is desired
    # @return [WinRM::Output] output object with stdout, stderr, and
    #   exit code
    def run_powershell_script(script_file, &block)
      # this code looks overly compact in an attempt to limit local
      # variable assignments that may contain large strings and
      # consequently bloat the Ruby VM
      run_cmd(
        'powershell',
        [
          '-encodedCommand',
          ::WinRM::PowershellScript.new(
            script_file.is_a?(IO) ? script_file.read : script_file
          ).encoded
        ],
        &block
      )
    end

    # Code page appropriate to os version. utf-8 (65001) is buggy pre win7/2k8r2
    # So send MS-DOS (437) for earlier versions
    #
    # @return [Integer] code page in use
    def code_page
      @code_page ||= os_version < Gem::Version.new('6.1') ? 437 : 65_001
    end

    # @return [Integer] the safe maximum number of commands that can
    #   be executed in one remote shell session
    def max_commands
      @max_commands ||= (os_version < Gem::Version.new('6.2') ? 15 : 1500) - 2
    end

    private

    # @return [Integer] the number of executed commands on the remote
    #   shell session
    # @api private
    attr_accessor :command_count

    # Creates a finalizer for this connection which will close the open
    # remote shell session when the object is garabage collected or on
    # Ruby VM shutdown.
    #
    # @param shell_id [String] the remote shell identifier
    # @api private
    def add_finalizer(shell_id)
      ObjectSpace.define_finalizer(self, self.class.finalize(shell_id, service))
    end

    # Ensures that there is an open remote shell session.
    #
    # @raise [WinRM::WinRMError] if there is no open shell
    # @api private
    def ensure_open_shell!
      fail ::WinRM::WinRMError, "#{self.class}#open must be called " \
        'before any run methods are invoked' if shell.nil?
    end

    # Fetches the OS build bersion of the remote endpoint
    #
    # @api private
    def os_version
      @os_version ||= begin
        version = nil
        wql = service.run_wql('select version from Win32_OperatingSystem')
        if wql[:xml_fragment]
          version = wql[:xml_fragment].first[:version] if wql[:xml_fragment].first[:version]
        end
        fail ::WinRM::WinRMError, 'Unable to determine endpoint os version' if version.nil?
        Gem::Version.new(version)
      end
    end

    # Removes any finalizers for this connection.
    #
    # @api private
    def remove_finalizer
      ObjectSpace.undefine_finalizer(self)
    end

    # Closes the remote shell session and opens a new one.
    #
    # @api private
    def reset
      service.logger.debug("Resetting WinRM shell (Max command limit is #{max_commands})")
      open
    end

    # Yields to a block and reties the block if certain rescuable
    # exceptions are raised.
    #
    # @param retries [Integer] the number of times to retry before failing
    # @option delay [Float] the number of seconds to wait until
    #   attempting a retry
    # @api private
    def retryable(retries, delay)
      yield
    rescue *RESCUE_EXCEPTIONS_ON_ESTABLISH.call => e
      if (retries -= 1) > 0
        service.logger.info("[WinRM] connection failed. retrying in #{delay} seconds: #{e.inspect}")
        sleep(delay)
        retry
      else
        service.logger.warn("[WinRM] connection failed, terminating (#{e.inspect})")
        raise
      end
    end

    RESCUE_EXCEPTIONS_ON_ESTABLISH = lambda do
      [
        Errno::EACCES, Errno::EADDRINUSE, Errno::ECONNREFUSED, Errno::ETIMEDOUT,
        Errno::ECONNRESET, Errno::ENETUNREACH, Errno::EHOSTUNREACH,
        ::WinRM::WinRMHTTPTransportError, ::WinRM::WinRMAuthorizationError,
        HTTPClient::KeepAliveDisconnected, HTTPClient::ConnectTimeoutError
      ].freeze
    end
  end
end
