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

require 'nori'
require 'rexml/document'
require 'securerandom'
require 'base64'
require_relative 'helpers/powershell_script'
require_relative 'wsmv/soap'
require_relative 'wsmv/header'
require_relative 'wsmv/create_shell'
require_relative 'wsmv/command'
require_relative 'wsmv/command_output'
require_relative 'wsmv/close_shell'
require_relative 'wsmv/wql_query'
require_relative 'wsmv/init_runspace_pool'
require_relative 'wsmv/keep_alive'

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
    def self.finalize(session_opts, xfer, shell_id, logger)
      proc { CommandExecutor.close_shell_final(session_opts, xfer, shell_id, logger) }
    end

    # @return [WinRM::WinRMWebService] a WinRM web service object
    attr_reader :service

    # @return [String,nil] the identifier for the current open remote
    #   shell session, or `nil` if the session is not open
    attr_reader :shell

    # Creates a CommandExecutor given a `WinRM::WinRMWebService` object.
    def initialize(session_opts, cmd_opts, xfer, os_version, logger = nil)
      @session_opts = session_opts
      @cmd_opts = cmd_opts
      @xfer = xfer
      @os_version = os_version
      @logger = logger || Logging.logger[self]
      @command_count = 0
    end

    # Closes the open remote shell session. This method can be called
    # multiple times, even if there is no open session.
    def close
      return unless @shell
      close_shell
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
      retryable(@session_opts[:retry_limit], @session_opts[:retry_delay]) do
        open_shell
      end
      add_finalizer
      @command_count = 0
      @shell
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
      reset if command_count > max_commands
      ensure_open_shell!

      @command_count += 1
      result = nil

      command_opts = {
        shell_id: @shell,
        command_id: SecureRandom.uuid.to_s.upcase,
        command: command,
        arguments: arguments
      }
      msg = WinRM::WSMV::Command.new(@session_opts, command_opts)
      resp_doc = @xfer.send_request(msg.build)
      command_id = REXML::XPath.first(resp_doc, "//#{WinRM::WSMV::SOAP::NS_WIN_SHELL}:CommandId").text

      output = get_command_output(command_id, &block)

      # TODO: ensure cleanup?
      msg = WinRM::WSMV::CommandOutput.new(@session_opts, shell_id: @shell, command_id: command_id)
      @xfer.send_request(msg.build)

      output
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
      @code_page ||= @os_version < 6.1 ? 437 : 65_001
    end

    # @return [Integer] the safe maximum number of commands that can
    #   be executed in one remote shell session
    def max_commands
      @max_commands ||= (@os_version < 6.2 ? 15 : 1500) - 2
    end

    private

    # @return [Integer] the number of executed commands on the remote
    #   shell session
    # @api private
    attr_accessor :command_count

    def open_shell
      @logger.debug("[WinRM] opening remote shell on #{@session_opts[:endpoint]}")
      # This doesn't support all the winrm_service.open_shell opts...
      msg = WSMV::CreateShell.new(@session_opts, codepage: code_page)
      resp_doc = @xfer.send_request(msg.build)
      @shell = REXML::XPath.first(resp_doc, "//*[@Name='ShellId']").text
      @logger.debug("[WinRM] remote shell #{@shell} is open on #{@session_opts[:endpoint]}")
    end

    def get_command_output(command_id, &block)
      out_opts = {
        shell_id: @shell,
        command_id: command_id
      }

      resp_doc = nil
      request_msg = WinRM::WSMV::CommandOutput.new(@session_opts, out_opts).build
      done_elems = []
      output = Output.new

      while done_elems.empty?
        resp_doc = send_get_output_message(request_msg)

        REXML::XPath.match(resp_doc, "//#{WinRM::WSMV::SOAP::NS_WIN_SHELL}:Stream").each do |n|
          next if n.text.nil? || n.text.empty?

          # decode and replace invalid unicode characters
          decoded_text = Base64.decode64(n.text).force_encoding('utf-8')
          if !decoded_text.valid_encoding?
            if decoded_text.respond_to?(:scrub!)
              decoded_text.scrub!
            else
              decoded_text = decoded_text.encode('utf-16', invalid: :replace, undef: :replace)
                .encode('utf-8')
            end
          end

          # remove BOM which 2008R2 applies
          stream = { n.attributes['Name'].to_sym => decoded_text.sub('\xEF\xBB\xBF', '') }
          output[:data] << stream
          yield stream[:stdout], stream[:stderr] if block_given?
        end

        # We may need to get additional output if the stream has not finished.
        # The CommandState will change from Running to Done like so:
        # @example
        #   from...
        #   <rsp:CommandState CommandId="..." State="http://schemas.microsoft.com/wbem/wsman/1/windows/shell/CommandState/Running"/>
        #   to...
        #   <rsp:CommandState CommandId="..." State="http://schemas.microsoft.com/wbem/wsman/1/windows/shell/CommandState/Done">
        #     <rsp:ExitCode>0</rsp:ExitCode>
        #   </rsp:CommandState>
        done_elems = REXML::XPath.match(resp_doc, "//*[@State='http://schemas.microsoft.com/wbem/wsman/1/windows/shell/CommandState/Done']")
      end

      output[:exitcode] = REXML::XPath.first(resp_doc, "//#{WinRM::WSMV::SOAP::NS_WIN_SHELL}:ExitCode").text.to_i
      output
    end

    def send_get_output_message(message)
      @xfer.send_request(message)
    rescue WinRMWSManFault => e
      # If no output is available before the wsman:OperationTimeout expires,
      # the server MUST return a WSManFault with the Code attribute equal to
      # 2150858793. When the client receives this fault, it SHOULD issue
      # another Receive request.
      # http://msdn.microsoft.com/en-us/library/cc251676.aspx
      if e.fault_code == '2150858793'
        @logger.debug("[WinRM] retrying receive request after timeout")
        retry
      else
        raise
      end
    end

    def close_shell
      CommandExecutor.close_shell_final(@session_opts, @xfer, @shell, @logger)
    end

    def self.close_shell_final(session_opts, xfer, shell_id, logger)
      logger.debug("[WinRM] closing remote shell #{shell_id} on #{session_opts[:endpoint]}")
      cmd_opts = {
        shell_id: shell_id
      }
      msg = WinRM::WSMV::CloseShell.new(session_opts, cmd_opts)
      resp = xfer.send_request(msg.build)
      logger.debug("[WinRM] remote shell #{shell_id} closed")
    end

    # Creates a finalizer for this connection which will close the open
    # remote shell session when the object is garabage collected or on
    # Ruby VM shutdown.
    #
    # @param shell_id [String] the remote shell identifier
    # @api private
    def add_finalizer
        ObjectSpace.define_finalizer(self, self.class.finalize(@session_opts, @xfer, @shell, @logger))
    end

    # Ensures that there is an open remote shell session.
    #
    # @raise [WinRM::WinRMError] if there is no open shell
    # @api private
    def ensure_open_shell!
      fail ::WinRM::WinRMError, "#{self.class}#open must be called " \
        'before any run methods are invoked' if shell.nil?
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
