# -*- encoding: utf-8 -*-
#
# Copyright 2016 Shawn Neal <sneal@sneal.net>
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

# rubocop:disable Metrics/MethodLength

module WinRM
  module WSMV
    # SOAP header utility mixin
    module Header
      # Merge the various header hashes and make sure we carry all of the attributes
      # through instead of overwriting them.
      def merge_headers(*headers)
        hdr = {}
        headers.each do |h|
          hdr.merge!(h) do |k, v1, v2|
            v1.merge!(v2) if k == :attributes!
          end
        end
        hdr
      end

      def shared_headers(session_opts)
        {
          "#{NS_ADDRESSING}:To" => "#{session_opts[:endpoint]}",
          "#{NS_ADDRESSING}:ReplyTo" => {
            "#{NS_ADDRESSING}:Address" =>
              'http://schemas.xmlsoap.org/ws/2004/08/addressing/role/anonymous',
            :attributes! => {
              "#{NS_ADDRESSING}:Address" => {
                'mustUnderstand' => true
              }
            }
          },
          "#{NS_WSMAN_DMTF}:MaxEnvelopeSize" => session_opts[:max_envelope_size],
          "#{NS_ADDRESSING}:MessageID" => "uuid:#{SecureRandom.uuid.to_s.upcase}",
          "#{NS_WSMAN_MSFT}:SessionId" => "uuid:#{session_opts[:session_id]}",
          "#{NS_WSMAN_DMTF}:Locale/" => '',
          "#{NS_WSMAN_MSFT}:DataLocale/" => '',
          "#{NS_WSMAN_DMTF}:OperationTimeout" =>
            Iso8601Duration.sec_to_dur(session_opts[:operation_timeout]),
          :attributes! => {
            "#{NS_WSMAN_DMTF}:MaxEnvelopeSize" => { 'mustUnderstand' => true },
            "#{NS_WSMAN_DMTF}:Locale/" => {
              'xml:lang' => session_opts[:locale], 'mustUnderstand' => false
            },
            "#{NS_WSMAN_MSFT}:DataLocale/" => {
              'xml:lang' => session_opts[:locale], 'mustUnderstand' => false
            },
            "#{NS_WSMAN_MSFT}:SessionId" => { 'mustUnderstand' => false }
          }
        }
      end
    end
  end
end

# rubocop:enable Metrics/MethodLength
