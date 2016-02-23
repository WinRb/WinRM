# encoding: UTF-8
#
# Copyright 2010 Dan Wanek <dan.wanek@gmail.com>
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

require 'nori'
require 'rexml/document'
require 'securerandom'
require 'winrm/command_executor'
require_relative 'helpers/powershell_script'
require_relative 'wsmv/soap'
require_relative 'wsmv/header'
require_relative 'wsmv/create_shell'
require_relative 'wsmv/command'
require_relative 'wsmv/command_output'
require_relative 'wsmv/close_shell'
require_relative 'wsmv/wql_query'
require_relative 'wsmv/init_runspace_pool'

module WinRM
  # This is the main class that does the SOAP request/response logic. There are a few helper
  # classes, but pretty much everything comes through here first.
  class WinRMWebService
    DEFAULT_TIMEOUT = 60
    DEFAULT_MAX_ENV_SIZE = 153600
    DEFAULT_LOCALE = 'en-US'

    include WinRM::WSMV::SOAP
    include WinRM::WSMV::Header

    attr_reader :retry_limit, :retry_delay

    attr_accessor :logger

    # @param [String,URI] endpoint the WinRM webservice endpoint
    # @param [Symbol] transport either :kerberos(default)/:ssl/:plaintext
    # @param [Hash] opts Misc opts for the various transports.
    #   @see WinRM::HTTP::HttpTransport
    #   @see WinRM::HTTP::HttpGSSAPI
    #   @see WinRM::HTTP::HttpNegotiate
    #   @see WinRM::HTTP::HttpSSL
    def initialize(endpoint, transport = :kerberos, opts = {})
      @session_opts = {
        endpoint: endpoint,
        max_envelope_size: DEFAULT_MAX_ENV_SIZE,
        session_id: SecureRandom.uuid.to_s.upcase,
        operation_timeout: DEFAULT_TIMEOUT,
        locale: DEFAULT_LOCALE
      }
      setup_logger
      configure_retries(opts)
      begin
        @xfer = send "init_#{transport}_transport", opts.merge({endpoint: endpoint})
      rescue NoMethodError => e
        raise "Invalid transport '#{transport}' specified, expected: negotiate, kerberos, plaintext, ssl."
      end
    end

    def init_negotiate_transport(opts)
      HTTP::HttpNegotiate.new(opts[:endpoint], opts[:user], opts[:pass], opts)
    end

    def init_kerberos_transport(opts)
      require 'gssapi'
      require 'gssapi/extensions'
      HTTP::HttpGSSAPI.new(opts[:endpoint], opts[:realm], opts[:service], opts[:keytab], opts)
    end

    def init_plaintext_transport(opts)
      HTTP::HttpPlaintext.new(opts[:endpoint], opts[:user], opts[:pass], opts)
    end

    def init_ssl_transport(opts)
      if opts[:basic_auth_only]
        HTTP::BasicAuthSSL.new(opts[:endpoint], opts[:user], opts[:pass], opts)
      else
        HTTP::HttpNegotiate.new(opts[:endpoint], opts[:user], opts[:pass], opts)
      end
    end

    # Operation timeout.
    #
    # Unless specified the client receive timeout will be 10s + the operation
    # timeout.
    #
    # @see http://msdn.microsoft.com/en-us/library/ee916629(v=PROT.13).aspx
    #
    # @param [Fixnum] The number of seconds to set the WinRM operation timeout
    # @param [Fixnum] The number of seconds to set the Ruby receive timeout
    # @return [String] The ISO 8601 formatted operation timeout
    def set_timeout(op_timeout_sec, receive_timeout_sec=nil)
      @session_opts[:operation_timeout] = op_timeout_sec
      @xfer.receive_timeout = receive_timeout_sec || op_timeout_sec + 10
      Iso8601Duration.sec_to_dur(@session_opts[:operation_timeout])
    end
    alias :op_timeout :set_timeout

    # The operation timeout
    def timeout
      Iso8601Duration.sec_to_dur(@session_opts[:operation_timeout])
    end

    # The WSMan http(s) endpoint
    def endpoint
      @session_opts[:endpoint]
    end

    # Max envelope size
    # @see http://msdn.microsoft.com/en-us/library/ee916127(v=PROT.13).aspx
    # @param [Fixnum] byte_sz the max size in bytes to allow for the response
    def max_env_size(byte_sz)
      @session_opts[:max_envelope_size] = byte_sz
    end

    # Set the locale
    # @see http://msdn.microsoft.com/en-us/library/gg567404(v=PROT.13).aspx
    # @param [String] locale the locale to set for future messages
    def locale(locale)
      @session_opts[:locale] = locale
    end

    # Create a Shell on the destination host
    # @param [Hash<optional>] shell_opts additional shell options you can pass
    # @option shell_opts [String] :i_stream Which input stream to open.  Leave this alone unless you know what you're doing (default: stdin)
    # @option shell_opts [String] :o_stream Which output stream to open.  Leave this alone unless you know what you're doing (default: stdout stderr)
    # @option shell_opts [String] :working_directory The directory to create the shell in
    # @option shell_opts [String] :codepage The shell code page, defaults to 65001 (UTF-8)
    # @option shell_opts [String] :noprofile The WINRS_NOPROFILE setting, defaults to 'FALSE'
    # @option shell_opts [Fixnum] :idle_timeout The shell IdleTimeOut in seconds
    # @option shell_opts [Hash] :env_vars environment variables to set for the shell. For instance;
    #   :env_vars => {:myvar1 => 'val1', :myvar2 => 'var2'}
    # @return [String] The ShellId from the SOAP response. This is our open shell instance on the remote machine.
    def open_shell(shell_opts = {}, &block)
      shell_id = SecureRandom.uuid.to_s.upcase
      logger.debug("[WinRM] opening remote shell on #{@session_opts[:endpoint]}")
      msg = WSMV::CreateShell.new(@session_opts, shell_opts)
      resp_doc = send_message(msg.build)
      # CMD shell returns a new shell_id
      shell_id = REXML::XPath.first(resp_doc, "//*[@Name='ShellId']").text
      logger.debug("[WinRM] remote shell #{shell_id} is open on #{@session_opts[:endpoint]}")

      if block_given?
        begin
          yield shell_id
        ensure
          close_shell(shell_id)
        end
      else
        shell_id
      end
    end

    # Run a command on a machine with an open shell
    # @param [String] shell_id The shell id on the remote machine.  See #open_shell
    # @param [String] command The command to run on the remote machine
    # @param [Array<String>] arguments An array of arguments for this command
    # @param [Hash<optional>] cmd_opts additional command options you can pass
    # @option cmd_opts [String] :console_mode_stdin The client-side mode for standard input is console if TRUE and pipe if FALSE.
    # @option cmd_opts [String] :skip_cmd_shell If set to TRUE, this option requests that the server runs the command without
    # using cmd.exe; if set to FALSE, the server is requested to use cmd.exe.
    # @return [String] The CommandId from the SOAP response. This is the ID we need to query in order to get output.
    def run_command(shell_id, command, arguments = [], cmd_opts = {}, &block)
      command_opts = {
        shell_id: shell_id,
        command_id: SecureRandom.uuid.to_s.upcase,
        command: command,
        arguments: arguments
      }.merge!(cmd_opts)
      msg = WSMV::Command.new(@session_opts, command_opts)

      resp_doc = send_message(msg.build)
      command_id = REXML::XPath.first(resp_doc, "//#{NS_WIN_SHELL}:CommandId").text

      if block_given?
        begin
          yield command_id
        ensure
          cleanup_command(shell_id, command_id)
        end
      else
        command_id
      end
    end

    def write_stdin(shell_id, command_id, stdin)
      stdin_opts = {
        shell_id: shell_id,
        command_id: command_id,
        stdin: stdin
      }
      msg = WSMV::WriteStdin.new(@session_opts, stdin_opts)
      resp = send_message(msg.build)
      true
    end

    # Get the Output of the given shell and command
    # @param [String] shell_id The shell id on the remote machine.  See #open_shell
    # @param [String] command_id The command id on the remote machine.  See #run_command
    # @return [Hash] Returns a Hash with a key :exitcode and :data.  Data is an Array of Hashes where the cooresponding key
    #   is either :stdout or :stderr.  The reason it is in an Array so so we can get the output in the order it ocurrs on
    #   the console.
    def get_command_output(shell_id, command_id, &block)
      cmd_out_opts = {
        shell_id: shell_id,
        command_id: command_id
      }

      resp_doc = nil
      request_msg = WinRM::WSMV::CommandOutput.new(@session_opts, cmd_out_opts).build
      done_elems = []
      output = Output.new

      while done_elems.empty?
        resp_doc = send_get_output_message(request_msg)

        REXML::XPath.match(resp_doc, "//#{NS_WIN_SHELL}:Stream").each do |n|
          next if n.text.nil? || n.text.empty?

          # decode and replace invalid unicode characters
          decoded_text = Base64.decode64(n.text).force_encoding('utf-8')
          if ! decoded_text.valid_encoding?
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

      output[:exitcode] = REXML::XPath.first(resp_doc, "//#{NS_WIN_SHELL}:ExitCode").text.to_i
      output
    end

    # Clean-up after a command. Signal the Command references to terminate (close stdout/stderr)
    # @see #run_command
    # @param [String] shell_id The shell id on the remote machine.  See #open_shell
    # @param [String] command_id The command id on the remote machine.  See #run_command
    # @return [true] This should have more error checking but it just returns true for now.
    def cleanup_command(shell_id, command_id)
      cmd_opts = {
        shell_id: shell_id,
        command_id: command_id
      }
      msg = WinRM::WSMV::CommandOutput.new(@session_opts, cmd_opts)
      resp = send_message(msg.build)
      true
    end

    # Close the shell
    # @param [String] shell_id The shell id on the remote machine.  See #open_shell
    # @return [true] This should have more error checking but it just returns true for now.
    def close_shell(shell_id)
      logger.debug("[WinRM] closing remote shell #{shell_id} on #{@session_opts[:endpoint]}")
      cmd_opts = {
        shell_id: shell_id
      }
      msg = WinRM::WSMV::CloseShell.new(@session_opts, cmd_opts)
      resp = send_message(msg.build)
      logger.debug("[WinRM] remote shell #{shell_id} closed")
      true
    end

    # DEPRECATED: Use WinRM::CommandExecutor#run_cmd instead
    # Run a CMD command
    # @param [String] command The command to run on the remote system
    # @param [Array <String>] arguments arguments to the command
    # @param [String] an existing and open shell id to reuse
    # @return [Hash] :stdout and :stderr
    def run_cmd(command, arguments = [], &block)
      logger.warn("WinRM::WinRMWebService#run_cmd is deprecated. Use WinRM::CommandExecutor#run_cmd instead")
      create_executor do |executor|
        executor.run_cmd(command, arguments, &block)
      end
    end
    alias :cmd :run_cmd

    # DEPRECATED: Use WinRM::CommandExecutor#run_powershell_script instead
    # Run a Powershell script that resides on the local box.
    # @param [IO,String] script_file an IO reference for reading the Powershell script or the actual file contents
    # @param [String] an existing and open shell id to reuse
    # @return [Hash] :stdout and :stderr
    def run_powershell_script(script_file, &block)
      logger.warn("WinRM::WinRMWebService#run_powershell_script is deprecated. Use WinRM::CommandExecutor#run_powershell_script instead")
      create_executor do |executor|
        executor.run_powershell_script(script_file, &block)
      end
    end
    alias :powershell :run_powershell_script

    # Creates a CommandExecutor initialized with this WinRMWebService
    # If called with a block, create_executor yields an executor and
    # ensures that the executor is closed after the block completes.
    # The CommandExecutor is simply returned if no block is given.
    # @yieldparam [CommandExecutor] a CommandExecutor instance
    # @return [CommandExecutor] a CommandExecutor instance
    def create_executor(&block)
      executor = CommandExecutor.new(self)
      executor.open

      if block_given?
        begin
          yield executor
        ensure
          executor.close
        end
      else
        executor
      end
    end

    # Run a WQL Query
    # @see http://msdn.microsoft.com/en-us/library/aa394606(VS.85).aspx
    # @param [String] wql The WQL query
    # @return [Hash] Returns a Hash that contain the key/value pairs returned from the query.
    def run_wql(wql)
      msg = WinRM::WSMV::WqlQuery.new(@session_opts, wql)
      resp = send_message(msg.build)
      parser = Nori.new(:parser => :rexml, :advanced_typecasting => false, :convert_tags_to => lambda { |tag| tag.snakecase.to_sym }, :strip_namespaces => true)
      hresp = parser.parse(resp.to_s)[:envelope][:body]

      # Normalize items so the type always has an array even if it's just a single item.
      items = {}
      if hresp[:enumerate_response][:items]
        hresp[:enumerate_response][:items].each_pair do |k,v|
          if v.is_a?(Array)
            items[k] = v
          else
            items[k] = [v]
          end
        end
      end
      items
    end
    alias :wql :run_wql

    def toggle_nori_type_casting(to)
      logger.warn('toggle_nori_type_casting is deprecated and has no effect, ' +
        'please remove calls to it')
    end

    private

    def setup_logger
      @logger = Logging.logger[self]
      @logger.level = :warn
      @logger.add_appenders(Logging.appenders.stdout)
    end

    def configure_retries(opts)
      @retry_delay = opts[:retry_delay] || 10
      @retry_limit = opts[:retry_limit] || 3
    end

    def send_get_output_message(message)
      send_message(message)
    rescue WinRMWSManFault => e
      # If no output is available before the wsman:OperationTimeout expires,
      # the server MUST return a WSManFault with the Code attribute equal to
      # 2150858793. When the client receives this fault, it SHOULD issue
      # another Receive request.
      # http://msdn.microsoft.com/en-us/library/cc251676.aspx
      if e.fault_code == '2150858793'
        logger.debug("[WinRM] retrying receive request after timeout")
        retry
      else
        raise
      end
    end

    def send_message(message)
      @xfer.send_request(message)
    end
  end # WinRMWebService
end # WinRM
