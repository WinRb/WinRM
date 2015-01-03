# encoding: UTF-8
#
# Copyright 2014 Shawn Neal <sneal@sneal.net>
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
  # Wraps a PowerShell script to make it easy to Base64 encode for transport
  class PowershellScript
    attr_reader :text

    # Creates a new PowershellScript object which can be used to encode
    # PS scripts for safe transport over WinRM.
    # @param [String] The PS script text content
    def initialize(script)
      @text = script
    end

    # Encodes the script so that it can be passed to the PowerShell
    # --EncodedCommand argument.
    # @return [String] The UTF-16LE base64 encoded script
    def encoded
      encoded_script = text.encode('UTF-16LE', 'UTF-8')
      Base64.strict_encode64(encoded_script)
    end
  end
end
