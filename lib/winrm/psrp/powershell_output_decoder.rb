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

require 'base64'
require_relative 'message'

module WinRM
  module PSRP
    # Handles decoding a raw powershell output response
    class PowershellOutputDecoder
      # Decode the raw SOAP output into decoded PSRP message,
      # Removes BOM and replaces encoded line endings
      # @param raw_output [String] The raw encoded output
      # @return [String] The decoded output
      def decode(message)
        case message.type
        when WinRM::PSRP::Message::MESSAGE_TYPES[:pipeline_output]
          decode_pipeline_output(message)
        when WinRM::PSRP::Message::MESSAGE_TYPES[:runspacepool_host_call]
          decode_host_call(message)
        when WinRM::PSRP::Message::MESSAGE_TYPES[:pipeline_host_call]
          decode_host_call(message)
        when WinRM::PSRP::Message::MESSAGE_TYPES[:error_record]
          decode_error_record(message)
        end
      end

      protected

      def decode_pipeline_output(message)
        message.parsed_data.output
      end

      def decode_host_call(message)
        text = begin
          case message.parsed_data.method_identifier
          when /WriteLine/, 'WriteErrorLine'
            "#{message.parsed_data.method_parameters[:s]}\r\n"
          when 'WriteDebugLine'
            "Debug: #{message.parsed_data.method_parameters[:s]}\r\n"
          when 'WriteWarningLine'
            "Warning: #{message.parsed_data.method_parameters[:s]}\r\n"
          when 'WriteVerboseLine'
            "Verbose: #{message.parsed_data.method_parameters[:s]}\r\n"
          when %r{Write\/[1-2]}
            message.parsed_data.method_parameters[:s]
          end
        end

        hex_decode(text)
      end

      def decode_error_record(message)
        doc = REXML::Document.new(message.data)
        doc.root.get_elements('//S').map do |node|
          text = ''
          text << "#{node.attributes['N']}: " if node.attributes['N']
          next unless node.text
          text << node.text.gsub(/_x(\h\h\h\h)_/) do
            Regexp.last_match[1].hex.chr
          end.chomp
          text << "\r\n"
        end.join
      end

      private

      def hex_decode(text)
        return unless text

        text.gsub(/_x(\h\h\h\h)_/) do
          Regexp.last_match[1].hex.chr
        end
      end
    end
  end
end
