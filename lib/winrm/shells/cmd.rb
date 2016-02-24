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

require_relative '../wsmv/cleanup_command'
require_relative '../wsmv/close_shell'
require_relative '../wsmv/command'
require_relative '../wsmv/command_output'
require_relative '../wsmv/command_output_processor'
require_relative '../wsmv/create_pipeline'
require_relative '../wsmv/create_shell'
require_relative '../wsmv/header'
require_relative '../wsmv/init_runspace_pool'
require_relative '../wsmv/keep_alive'
require_relative '../wsmv/soap'
require_relative '../wsmv/wql_query'
require_relative '../http/transport'
require_relative '../core/retryable'

module WinRM
  module Shells
    class Cmd
      include WinRM::Core::Retryable

      def initialize(connection_opts, transport, logger)
        @connection_opts = connection_opts
        @transport = transport
        @logger = logger
        @command_count = 0
      end

      def run(command, arguments = [], &block)
        open if @command_count > @connection_opts[:max_commands] || !@shell_id
        @command_count += 1

        # send the command
        command_id = SecureRandom.uuid.to_s.upcase
        cmd_opts = {
          shell_id: @shell_id,
          command_id: command_id,
          command: command,
          arguments: arguments
        }
        msg = WinRM::WSMV::Command.new(@connection_opts, cmd_opts)
        resp_doc = @transport.send_request(msg.build)
        command_id = REXML::XPath.first(
          resp_doc,
          "//#{WinRM::WSMV::SOAP::NS_WIN_SHELL}:CommandId").text

        # get the command output
        out_processor = WinRM::WSMV::CommandOutputProcessor.new(@connection_opts, @transport)
        output = out_processor.command_output(@shell_id, command_id, &block)

        # cleanup the command IO
        cmd_opts = {
          shell_id: @shell_id,
          command_id: command_id
        }
        msg = WinRM::WSMV::CleanupCommand.new(@connection_opts, cmd_opts)
        @transport.send_request(msg.build)

        output
      end

      private

      def open
        close
        retryable(@connection_opts[:retry_limit], @connection_opts[:retry_delay]) do
          msg = WinRM::WSMV::CreateShell.new(@connection_opts)
          resp_doc = @transport.send_request(msg.build)
          @shell_id = REXML::XPath.first(resp_doc, "//*[@Name='ShellId']").text
        end
        add_finalizer
        @command_count = 0
      end

      def close
        return unless @shell_id
        Cmd.close_shell(@connection_opts, @transport, @shell_id)
        remove_finalizer
        @shell_id = nil
      end

      def add_finalizer
        ObjectSpace.define_finalizer(self, self.class.finalize(@connection_opts, @transport, @shell_id))
      end

      def remove_finalizer
        ObjectSpace.undefine_finalizer(self)
      end

      def self.close_shell(connection_opts, transport, shell_id)
        msg = WinRM::WSMV::CloseShell.new(connection_opts, shell_id: shell_id)
        transport.send_request(msg.build)
      end

      def self.finalize(connection_opts, transport, shell_id)
        proc { Cmd.close_shell(connection_opts, transport, shell_id) }
      end
    end
  end
end
