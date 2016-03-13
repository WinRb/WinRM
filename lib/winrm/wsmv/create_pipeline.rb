# -*- encoding: utf-8 -*-
#
# Copyright 2016 Matt Wrock <matt@mattwrock.com>
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
require_relative '../psrp/message_factory'

module WinRM
  module WSMV
    # WSMV message to execute a command via psrp
    class CreatePipeline < Base
      attr_accessor :shell_id, :command_id, :command

      def initialize(session_opts, shell_id, command)
        @command_id = SecureRandom.uuid.to_s.upcase
        @session_opts = session_opts
        @shell_id = shell_id
        @command = command
      end

      protected

      def create_header(header)
        header << Gyoku.xml(command_headers)
      end

      def create_body(body)
        body.tag!("#{NS_WIN_SHELL}:CommandLine", 'CommandId' => command_id) do |cl|
          cl << Gyoku.xml(command_body)
        end
      end

      private

      def command_body
        pipeline = PSRP::MessageFactory.create_pipeline_message(3, shell_id, command_id, command)
        {
          "#{NS_WIN_SHELL}:Command" => 'Invoke-Expression',
          "#{NS_WIN_SHELL}:Arguments" => encode_bytes(pipeline.bytes)
        }
      end

      def command_headers
        merge_headers(shared_headers(@session_opts),
                      resource_uri_shell(RESOURCE_URI_POWERSHELL),
                      action_command,
                      selector_shell_id(shell_id))
      end
    end
  end
end
