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
  module Protocol
    class WinRM < Base
      def open
        envelope = write_envelope(action_create, create_option_set) do |body|
          body.tag!("#{NS_WIN_SHELL}:Shell") { |s| s << Gyoku.xml(shell_body) }
        end

        resp_doc = send_message(envelope)
        shell_id = REXML::XPath.first(resp_doc, "//*[@Name='ShellId']").text
 
        logger.debug("[WinRM] remote shell #{shell_id} is open on #{@endpoint}")

        shell_id
      end

      def resource_uri
        {"#{NS_WSMAN_DMTF}:ResourceURI" => 'http://schemas.microsoft.com/wbem/wsman/1/windows/shell/cmd',
          :attributes! => {"#{NS_WSMAN_DMTF}:ResourceURI" => {'mustUnderstand' => true}}}
      end

      def input_streams
        ['stdin']
      end

      def output_streams
        ['stdout', 'stderr']
      end

      def shell_body
        body = shell_body_streams
        body["#{NS_WIN_SHELL}:WorkingDirectory"] = working_directory if working_directory
        body["#{NS_WIN_SHELL}:IdleTimeOut"] = idle_timeout if idle_timeout

        if(options.has_key?(:env_vars) && options[:env_vars].is_a?(Hash))
          keys = options[:env_vars].keys
          vals = options[:env_vars].values
          body["#{NS_WIN_SHELL}:Environment"] = {
            "#{NS_WIN_SHELL}:Variable" => vals,
            :attributes! => {"#{NS_WIN_SHELL}:Variable" => {'Name' => keys}}
          }
        end
        body
      end

      protected

      def create_option_set
        @option_set ||= {
          "#{NS_WSMAN_DMTF}:OptionSet" => {
            "#{NS_WSMAN_DMTF}:Option" => [noprofile, codepage],
            :attributes! => {
              "#{NS_WSMAN_DMTF}:Option" => {
                'Name' => ['WINRS_NOPROFILE','WINRS_CODEPAGE']
              }
            }
          }
        }
      end

      private

      def codepage
        # utf8 as default codepage (from https://msdn.microsoft.com/en-us/library/dd317756(VS.85).aspx)
        @codepage ||= options.has_key?(:codepage) ? options[:codepage] : 65001
      end

      def noprofile
        @noprofile ||= options.has_key?(:noprofile) ? options[:noprofile] : 'FALSE'
      end

      def working_directory
        @working_directory ||= options[:working_directory]
      end

      def idle_timeout
        @idle_timeout ||= options[:idle_timeout] if options[:idle_timeout].is_a?(String)
      end
    end
  end
end
