# encoding: UTF-8
#
# Copyright 2016 Matt Wrock <matt@mattwrock.com>
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

require_relative 'fragment'

module WinRM
  # PowerShell Remoting Protcol module
  module PSRP
    # PowerShell Remoting Protocol message fragmenter.
    class MessageDefragmenter
      def initialize
        @messages = {}
      end

      def defragment(base64_bytes)
        # fragment = Fragment.new (
        #   bytes[0..7].reverse.unpack('Q')[0],
        #   message.bytes,
        #   bytes[21..-1],
        #   bytes[16].unpack('C')[0][0] == 1,
        #   bytes[16].unpack('C')[0][1] == 1,
        # )
        bytes = Base64.decode64(base64_bytes)

        Message.new(
          '00000000-0000-0000-0000-000000000000',
          bytes[25..28].unpack('V')[0],
          bytes[61..(bytes.length - 1)],
          '00000000-0000-0000-0000-000000000000',
          bytes[21..24].unpack('V')[0]
        )
      end
    end
  end
end
