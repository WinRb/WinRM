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

require 'securerandom'
require_relative 'retryable'
require_relative '../http/transport'
require_relative '../wsmv/cleanup_command'
require_relative '../wsmv/close_shell'
require_relative '../wsmv/command'
require_relative '../wsmv/command_output'
require_relative '../wsmv/command_output_processor'
require_relative '../wsmv/create_shell'
require_relative '../wsmv/create_pipeline'
require_relative '../wsmv/init_runspace_pool'
require_relative '../wsmv/keep_alive'
require_relative '../wsmv/soap'

module WinRM
  module Shells
    class PowerShell
      include Retryable

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
        pipeline_msg = WinRM::WSMV::CreatePipeline.new(@connection_opts, @shell_id, command)
        @transport.send_request(pipeline_msg.build)

        # get the command output
        out_processor = WinRM::WSMV::CommandOutputProcessor.new(@connection_opts, @transport)
        output = out_processor.command_output(@shell_id, pipeline_msg.command_id, &block)

        # cleanup the command IO
        cmd_opts = {
          shell_id: @shell_id,
          command_id: pipeline_msg.command_id
        }
        cleanup_msg = WinRM::WSMV::CleanupCommand.new(@connection_opts, cmd_opts)
        @transport.send_request(cleanup_msg.build)

        output
      end

      private

      def open
        close
        retryable(@connection_opts[:retry_limit], @connection_opts[:retry_delay]) do
          runspace_msg = WinRM::WSMV::InitRunspacePool.new(@connection_opts)
          resp_doc = @transport.send_request(runspace_msg.build)
          @shell_id = REXML::XPath.first(resp_doc, "//*[@Name='ShellId']").text
        end
        keepalive_msg = WinRM::WSMV::KeepAlive.new(@connection_opts, @shell_id)
        @transport.send_request(keepalive_msg.build)
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
