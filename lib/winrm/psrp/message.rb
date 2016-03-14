# encoding: UTF-8
#
# Copyright 2015 Matt Wrock <matt@mattwrock.com>
# Copyright 2016 Shawn Neal <sneal@sneal.net>
#
# Licensed under the Apache License, Version 2.0 (the 'License');
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an 'AS IS' BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

require_relative 'uuid'

module WinRM
  # PowerShell Remoting Protcol module
  module PSRP
    # PowerShell Remoting Protocol base message.
    # http://download.microsoft.com/download/9/5/E/95EF66AF-9026-4BB0-A41D-A4F81802D92C/%5BMS-PSRP%5D.pdf
    class Message
      include UUID

      # Length of all the blob header fields:
      # BOM, pipeline_id, runspace_pool_id, message_type, blob_destination
      BLOB_HEADER_LEN = 43

      # Maximum allowed length of the blob
      BLOB_MAX_LEN = 32_768 - BLOB_HEADER_LEN

      CLIENT_DESTINATION = 1
      SERVER_DESTINATION = 2

      # All known PSRP message types
      MESSAGE_TYPES = {
        session_capability:         0x00010002,
        init_runspacepool:          0x00010004,
        public_key:                 0x00010005,
        encrypted_session_key:      0x00010006,
        public_key_request:         0x00010007,
        connect_runspacepool:       0x00010008,
        runspace_init_data:         0x0002100b,
        reset_runspace_state:       0x0002100c,
        set_max_runspaces:          0x00021002,
        set_min_runspaces:          0x00021003,
        runspace_availability:      0x00021004,
        runspacepool_state:         0x00021005,
        create_pipeline:            0x00021006,
        get_available_runspaces:    0x00021007,
        user_event:                 0x00021008,
        application_private_data:   0x00021009,
        get_command_metadata:       0x0002100a,
        runspacepool_host_call:     0x00021100,
        runspacepool_host_response: 0x00021101,
        pipeline_input:             0x00041002,
        end_of_pipeline_input:      0x00041003,
        pipeline_output:            0x00041004,
        error_record:               0x00041005,
        pipeline_state:             0x00041006,
        debug_record:               0x00041007,
        verbose_record:             0x00041008,
        warning_record:             0x00041009,
        progress_record:            0x00041010,
        information_record:         0x00041011,
        pipeline_host_call:         0x00041100,
        pipeline_host_response:     0x00041101
      }

      # Creates a new PSRP message instance
      # @param message_parts [Hash]
      # @option object_id [Fixnum] The incrementing fragment id.
      # @option runspace_pool_id [String] The UUID of the remote shell/runspace pool.
      # @option pipeline_id [String] The UUID to correlate the command/pipeline response
      # @option message_type [Fixnum] The PSRP MessageType. This is most commonly
      # specified in hex, e.g. 0x00010002.
      # @option data [String] The PSRP payload as serialized XML
      # @option end_fragment [Boolean] If the fragment is the last fragment
      # @option start_fragment [Boolean] If the fragment is the first fragment
      # @option destination [Fixnum] The destination for this message - client or server
      # @option fragment_id [Fixnum] The id of this fragment
      def initialize(message_parts)
        message_parts.merge!(default_parts)

        fail 'runspace_pool_id cannot be nil' unless message_parts[:runspace_pool_id]
        unless MESSAGE_TYPES.values.include?(message_parts[:message_type])
          fail 'invalid message type'
        end
        fail 'data cannot be nil' unless message_parts[:data]

        @data = message_parts[:data]
        @destination = message_parts[:destination]
        @end_fragment = message_parts[:end_fragment]
        @fragment_id = message_parts[:fragment_id]
        @message_type = message_parts[:message_type]
        @object_id = message_parts[:object_id]
        @pipeline_id = message_parts[:pipeline_id]
        @runspace_pool_id = message_parts[:runspace_pool_id]
        @start_fragment = message_parts[:start_fragment]
      end

      attr_reader :object_id, :fragment_id, :end_fragment, :start_fragment
      attr_reader :destination, :message_type, :runspace_pool_id, :pipeline_id, :data

      # Returns the raw PSRP message bytes ready for transfer to Windows inside a
      # WinRM message.
      # @return [Array<Byte>] Unencoded raw byte array of the PSRP message.
      def bytes
        if data_bytes.length > BLOB_MAX_LEN
          fail "data cannot be greater than #{BLOB_MAX_LEN} bytes"
        end

        [
          int64be(object_id),
          int64be(fragment_id),
          end_start_fragment,
          blob_length,
          int16le(destination),
          int16le(message_type),
          uuid_to_windows_guid_bytes(runspace_pool_id),
          uuid_to_windows_guid_bytes(pipeline_id),
          byte_order_mark,
          data_bytes
        ].flatten
      end

      private

      def default_parts
        {
          fragment_id: 0,
          end_fragment: true,
          start_fragment: true,
          destination: SERVER_DESTINATION
        }
      end

      def end_start_fragment
        end_start = 0
        end_start += 0b10 if end_fragment
        end_start += 0b1 if start_fragment
        [end_start]
      end

      def blob_length
        int16be(data_bytes.length + BLOB_HEADER_LEN)
      end

      def byte_order_mark
        [239, 187, 191]
      end

      def data_bytes
        @data_bytes ||= data.force_encoding('utf-8').bytes
      end

      def int64be(int64)
        [int64 >> 32, int64 & 0x00000000ffffffff].pack('N2').unpack('C8')
      end

      def int16be(int16)
        [int16].pack('N').unpack('C4')
      end

      def int16le(int16)
        [int16].pack('N').unpack('C4').reverse
      end
    end
  end
end
