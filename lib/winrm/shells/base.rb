# -*- encoding: utf-8 -*-
#
# Copyright 2016 Shawn Neal <sneal@sneal.net>
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

require_relative 'retryable'
require_relative '../http/transport'
require_relative '../wsmv/cleanup_command'
require_relative '../wsmv/close_shell'
require_relative '../wsmv/command'
require_relative '../wsmv/command_output'
require_relative '../wsmv/command_output_processor'
require_relative '../wsmv/create_shell'
require_relative '../wsmv/soap'

module WinRM
  module Shells
    # Base class for remote shell
    class Base
      FAULTS_FOR_RESET = [
        '2150858843', # Shell has been closed
        '2147943418', # Error reading registry key
        '2150859174', # Maximum commands per user exceeded
      ].freeze

      include Retryable

      # Create a new Cmd shell
      # @param connection_opts [ConnectionOpts] The WinRM connection options
      # @param transport [HttpTransport] The WinRM SOAP transport
      # @param logger [Logger] The logger to log diagnostic messages to
      def initialize(connection_opts, transport, logger)
        @connection_opts = connection_opts
        @transport = transport
        @logger = logger
      end

      # @return [String] shell id of the currently opn shell or nil if shell is closed
      attr_reader :shell_id

      # @return [String] uri that SOAP calls use to identify shell type
      attr_reader :shell_uri

      # @return [ConnectionOpts] connection options of the shell
      attr_reader :connection_opts

      # @return [WinRM::HTTP::HttpTransport] transport used to talk with endpoint
      attr_reader :transport

      # @return [Logger] logger used for diagnostic messages
      attr_reader :logger

      # Runs the specified command with optional arguments
      # @param command [String] The command or executable to run
      # @param arguments [Array] The optional command arguments
      # @param block [&block] The optional callback for any realtime output
      # @return [WinRM::Output] The command output
      def run(command, arguments = [], &block)
        tries ||= 2

        open unless shell_id
        command_id = send_command(command, arguments)
        output_processor.command_output(shell_id, command_id, &block)
      rescue WinRMWSManFault => e
        raise unless FAULTS_FOR_RESET.include?(e.fault_code) && (tries -= 1) > 0
        logger.debug('[WinRM] opening new shell since the current one was deleted')
        @shell_id = nil
        retry
      ensure
        cleanup_command(command_id) if command_id
      end

      # Closes the shell if oneis open
      def close
        return unless shell_id
        self.class.close_shell(connection_opts, transport, shell_id)
        remove_finalizer
        @shell_id = nil
      end

      protected

      def send_command(_command, _arguments)
        raise NotImplementedError
      end

      def output_processor
        raise NotImplementedError
      end

      def open_shell
        raise NotImplementedError
      end

      private

      def cleanup_command(command_id)
        cleanup_msg = WinRM::WSMV::CleanupCommand.new(
          connection_opts,
          shell_uri: shell_uri,
          shell_id: shell_id,
          command_id: command_id)
        transport.send_request(cleanup_msg.build)
      end

      def open
        close
        retryable(connection_opts[:retry_limit], connection_opts[:retry_delay]) do
          logger.debug("[WinRM] opening remote shell on #{connection_opts[:endpoint]}")
          @shell_id = open_shell
        end
        logger.debug("[WinRM] remote shell created with shell_id: #{shell_id}")
        add_finalizer
      end

      def add_finalizer
        ObjectSpace.define_finalizer(
          self,
          self.class.finalize(connection_opts, transport, shell_id))
      end

      def remove_finalizer
        ObjectSpace.undefine_finalizer(self)
      end
    end
  end
end
