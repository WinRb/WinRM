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

require_relative 'powershell_output_decoder'

module WinRM
  module WSMV
    # Class to handle getting all the output of a command until it completes
    class PowershellOutputProcessor < CommandOutputProcessor
      # Creates a new command output processor
      # @param connection_opts [ConnectionOpts] The WinRM connection options
      # @param transport [HttpTransport] The WinRM SOAP transport
      # @param out_opts [Hash] Additional output options
      def initialize(connection_opts, transport, logger, out_opts = {})
        super
        @output_decoder = PowershellOutputDecoder.new
      end

      # Gets the command output from the remote shell
      # @param shell_id [UUID] The remote shell id running the command
      # @param command_id [UUID] The command id to get output for
      # @param block Optional callback for any output
      def command_output(shell_id, command_id, &block)
        resp_doc = nil
        output = WinRM::Output.new
        out_message = command_output_message(shell_id, command_id)
        until command_done?(resp_doc)
          resp_doc = send_get_output_message(out_message)
          REXML::XPath.match(resp_doc, "//#{NS_WIN_SHELL}:Stream").each do |n|
            next if n.text.nil? || n.text.empty?
            message, decoded_text = @output_decoder.decode(n.text)
            next unless  decoded_text
            stream = { stream_type(message) => decoded_text }
            output[:data] << stream

            yield stream[:stdout], stream[:stderr] if block
          end
        end
        output[:exitcode] = exit_code(resp_doc)
        output
      end

      private

      def stream_type(message)
        type = :stdout
        case message.message_type
        when WinRM::PSRP::Message::MESSAGE_TYPES[:error_record]
          type = :stderr
        when WinRM::PSRP::Message::MESSAGE_TYPES[:pipeline_host_call]
          type = :stderr if message.data.include?('WriteError')
        end
        type
      end
    end
  end
end
