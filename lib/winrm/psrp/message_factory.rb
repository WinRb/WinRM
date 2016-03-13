# encoding: UTF-8
#
# Copyright 2016 Shawn Neal <sneal@sneal.net>
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

require 'erubis'
require_relative 'message'

module WinRM
  module PSRP
    # Creates WinRM::PSRP::Message instances for various PSRP messages
    class MessageFactory
      class << self
        # Creates a new session capability PSRP message.
        # @param id [Fixnum] The incrementing fragment id.
        # @param runspace_pool_id [String] The UUID of the remote shell/runspace pool.
        def session_capability_message(id, runspace_pool_id)
          Message.new(
            object_id: id,
            runspace_pool_id: runspace_pool_id,
            message_type: 0x00010002,
            data: render('session_capability')
          )
        end

        # Creates a new init runspace pool PSRP message.
        # @param id [Fixnum] The incrementing fragment id.
        # @param runspace_pool_id [String] The UUID of the remote shell/runspace pool.
        def init_runspace_pool_message(id, runspace_pool_id)
          Message.new(
            object_id: id,
            runspace_pool_id: runspace_pool_id,
            message_type: 0x00010004,
            data: render('init_runspace_pool')
          )
        end

        # Creates a new PSRP message that creates pipline to execute a command.
        # @param id [Fixnum] The incrementing fragment id.
        # @param runspace_pool_id [String] The UUID of the remote shell/runspace pool.
        # @param pipeline_id [String] The UUID to correlate the command/pipeline
        # response.
        # @param command [String] The command passed to Invoke-Expression.
        def create_pipeline_message(id, runspace_pool_id, pipeline_id, command)
          Message.new(
            object_id: id,
            runspace_pool_id: runspace_pool_id,
            pipeline_id: pipeline_id,
            message_type: 0x00021006,
            data: render('create_pipeline', command: command)
          )
        end

        # rubocop:disable Metrics/AbcSize
        # Creates a new PSRP message from raw bytes
        # @param bytes [String] string representing the bytes of a PSRP message
        def parse_bytes(bytes)
          # Using "empty" guids for now because deserializing is painful
          # and currently not needed
          Message.new(
            object_id: bytes[0..7].reverse.unpack('Q')[0],
            runspace_pool_id: '00000000-0000-0000-0000-000000000000',
            pipeline_id: '00000000-0000-0000-0000-000000000000',
            message_type: bytes[25..28].unpack('V')[0],
            data: bytes[61..(bytes.length - 1)],
            fragment_id: bytes[8..15].reverse.unpack('Q')[0],
            end_fragment: bytes[16].unpack('C')[0][1] == 1,
            start_fragment: bytes[16].unpack('C')[0][0] == 1,
            destination: bytes[21..24].unpack('V')[0]
          )
        end
        # rubocop:enable Metrics/AbcSize

        private

        # Renders the specified template with the given context
        # @param template [String] The base filename of the PSRP message template.
        # @param context [Hash] Any options required for rendering the template.
        # @return [String] The rendered XML PSRP message.
        # @api private
        def render(template, context = nil)
          template_path = File.expand_path(
            "#{File.dirname(__FILE__)}/#{template}.xml.erb")
          template = File.read(template_path)
          Erubis::Eruby.new(template).result(context)
        end
      end
    end
  end
end
