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

module WinRM
  module WSMV
    # mixin for iterating streams in WSMAN responses
    module ResponseStreamReader
      include WinRM::WSMV::SOAP

      def read_streams(response_document)
        REXML::XPath.match(response_document, "//#{NS_WIN_SHELL}:Stream").each do |stream|
          next if stream.text.nil? || stream.text.empty?
          yield type: stream.attributes['Name'].to_sym, text: stream.text
        end
      end
    end
  end
end
