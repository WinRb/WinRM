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

require_relative 'message_defragmenter'
require_relative 'powershell_output_decoder'

module WinRM
  module PSRP
    # Class to handle getting all the output of a command until it completes
    class PowershellOutputProcessor < WSMV::CommandOutputProcessor
      # Creates a new command output processor
      # @param connection_opts [ConnectionOpts] The WinRM connection options
      # @param transport [HttpTransport] The WinRM SOAP transport
      # @param out_opts [Hash] Additional output options
      def initialize(connection_opts, transport, logger, out_opts = {})
        super
        @output_decoder = PowershellOutputDecoder.new
        @message_defragmenter = MessageDefragmenter.new
      end

      protected

      def handle_stream(stream, output)
        message = @message_defragmenter.defragment(stream[:text])
        return unless message
        decoded_text = @output_decoder.decode(message)
        return unless decoded_text

        out = { stream_type(message) => decoded_text }
        output[:data] << out
        [out[:stdout], out[:stderr]]
      end

      def stream_type(message)
        type = :stdout
        case message.type
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
