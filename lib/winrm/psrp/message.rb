# encoding: UTF-8
#
# Copyright 2015 Matt Wrock <matt@mattwrock.com>
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

module WinRM
  # PowerShell Remoting Protcol module
  module PSRP
    # PowerShell Remoting Protocol base message.
    # http://download.microsoft.com/download/9/5/E/95EF66AF-9026-4BB0-A41D-A4F81802D92C/%5BMS-PSRP%5D.pdf
    class Message
      include WinRM::UUIDHelper

      # Length of all the blob header fields:
      # BOM, pipeline_id, runspace_pool_id, message_type, blob_destination
      BLOB_HEADER_LEN = 43

      # Maximum allowed length of the blob
      BLOB_MAX_LEN = 32768 - BLOB_HEADER_LEN

      # All known PSRP message types
      MESSAGE_TYPES = [
        0x00010002,
        0x00010004,
        0x00010005,
        0x00010006,
        0x00010007,
        0x00010008,
        0x0002100B,
        0x0002100C,
        0x00021002,
        0x00021003,
        0x00021004,
        0x00021005,
        0x00021006,
        0x00021007,
        0x00021008,
        0x00021009,
        0x0002100A,
        0x00021100,
        0x00021101,
        0x00041002,
        0x00041003,
        0x00041004,
        0x00041005,
        0x00041006,
        0x00041007,
        0x00041008,
        0x00041009,
        0x00041010,
        0x00041011,
        0x00041100,
        0x00041101
      ]

      # Creates a new PSRP message instance
      # @param id [Fixnum] The incrementing fragment id.
      # @param shell_id [String] The UUID of the remote shell/runspace pool.
      # @param command_id [String] The UUID to correlate the command/pipeline
      # response.
      # @param message_type [Fixnum] The PSRP MessageType. This is most commonly
      # specified in hex, e.g. 0x00010002.
      # @param payload [String] The PSRP payload as serialized XML
      def initialize(id, shell_id, command_id, message_type, payload)
        raise 'shell_id cannot be nil' if shell_id.nil?
        raise 'invalid message type' unless MESSAGE_TYPES.include?(message_type)
        raise 'payload cannot be nil' if payload.nil?
        @id = id
        @shell_id = shell_id
        @command_id = command_id
        @message_type = message_type
        @payload = payload
      end

      # Returns the raw PSRP message bytes ready for transfer to Windows inside a
      # WinRM message.
      # @return [Array<Byte>] Unencoded raw byte array of the PSRP message.
      def bytes
        raise "payload cannot be greater than #{BLOB_MAX_LEN} bytes" if blob_bytes.length > BLOB_MAX_LEN
        message = message_id
        message += fragment_id
        message += end_start_fragment
        message += blob_length
        message += blob_destination
        message += message_type
        message += runspace_pool_id
        message += pipeline_id
        message += byte_order_mark
        message += blob_bytes
      end

      private

      def message_id
        int64be(@id)
      end

      def fragment_id
        # TODO: support multiple fragments
        int64be(0)
      end

      def end_start_fragment
        [3]
      end

      def blob_length
        int16be(blob_bytes.length + BLOB_HEADER_LEN)
      end

      def blob_destination
        [2, 0, 0, 0]
      end

      def message_type
        int16le(@message_type)
      end

      def runspace_pool_id
        uuid_to_windows_guid_bytes(@shell_id)
      end

      def pipeline_id
        uuid_to_windows_guid_bytes(@command_id)
      end

      def byte_order_mark
        [239, 187, 191]
      end

      def blob_bytes
        @payload_bytes ||= @payload.force_encoding('utf-8').bytes
      end

      def int64be(int64)
        [int64 >> 32, int64 & 0x00000000ffffffff].pack("N2").unpack("C8")
      end

      def int16be(int16)
        [int16].pack("N").unpack("C4")
      end

      def int16le(int16)
        [int16].pack("N").unpack("C4").reverse
      end
    end
  end
end
