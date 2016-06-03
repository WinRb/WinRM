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

require_relative 'base'

module WinRM
  module Shells
    # Proxy to a remote cmd.exe shell
    class Cmd < Base
      class << self
        def finalize(connection_opts, transport, shell_id)
          proc { Cmd.close_shell(connection_opts, transport, shell_id) }
        end

        def close_shell(connection_opts, transport, shell_id)
          msg = WinRM::WSMV::CloseShell.new(connection_opts, shell_id: shell_id)
          transport.send_request(msg.build)
        end
      end

      protected

      def send_command(command, arguments)
        cmd_msg = WinRM::WSMV::Command.new(
          connection_opts,
          shell_id: shell_id,
          command: command,
          arguments: arguments
        )
        transport.send_request(cmd_msg.build)
        logger.debug("[WinRM] Command created for #{command} with id: #{cmd_msg.command_id}")
        cmd_msg.command_id
      end

      def output_processor
        @output_processor ||= WinRM::WSMV::CommandOutputProcessor.new(
          connection_opts,
          transport,
          logger
        )
      end

      def open_shell
        msg = WinRM::WSMV::CreateShell.new(connection_opts)
        resp_doc = transport.send_request(msg.build)
        REXML::XPath.first(resp_doc, "//*[@Name='ShellId']").text
      end
    end
  end
end
