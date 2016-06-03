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
    class MessageFragmenter
      def initialize
        @object_id = 0
      end

      attr_reader :object_id

      def fragment(message)
        @object_id += 1
        [Fragment.new(object_id, message.bytes)]
      end
    end
  end
end
