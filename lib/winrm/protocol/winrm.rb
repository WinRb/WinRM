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
    # Constructs MS-WSMV protocol SOAP messages for WinRM messages
    class WinRM < Base
      def run_command(shell_id, command, arguments = [])
        cmd_envelope = write_envelope(action_command, command_option_set, shell_id) do |env_body|
          env_body.tag!("#{NS_WIN_SHELL}:CommandLine") do |s|
            s << Gyoku.xml(
              "#{NS_WIN_SHELL}:Command" => "\"#{command}\"",
              "#{NS_WIN_SHELL}:Arguments" => arguments
            )
          end
        end

        # Grab the command element and unescape any single quotes - issue 69
        xml = cmd_envelope.target!
        escaped_cmd = /<#{NS_WIN_SHELL}:Command>(.+)<\/#{NS_WIN_SHELL}:Command>/m.match(xml)[1]
        xml[escaped_cmd] = escaped_cmd.gsub(/&#39;/, "'")

        REXML::XPath.first(transport.send_request(xml), "//#{NS_WIN_SHELL}:CommandId").text
      end

      def resource_uri
        {
          "#{NS_WSMAN_DMTF}:ResourceURI" => 'http://schemas.microsoft.com/wbem/wsman/1/windows/shell/cmd',
          attributes!: { "#{NS_WSMAN_DMTF}:ResourceURI" => { 'mustUnderstand' => true } }
        }
      end

      def input_streams
        ['stdin']
      end

      def output_streams
        %w(stdout stderr)
      end

      def shell_body
        body = shell_body_streams
        body["#{NS_WIN_SHELL}:WorkingDirectory"] = working_directory if working_directory
        body["#{NS_WIN_SHELL}:IdleTimeOut"] = idle_timeout if idle_timeout

        if options.key?(:env_vars) && options[:env_vars].is_a?(Hash)
          body["#{NS_WIN_SHELL}:Environment"] = {
            "#{NS_WIN_SHELL}:Variable" => options[:env_vars].values,
            :attributes! => { "#{NS_WIN_SHELL}:Variable" => { 'Name' => options[:env_vars].keys } }
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
                'Name' => %w(WINRS_NOPROFILE WINRS_CODEPAGE)
              }
            }
          }
        }
      end

      def command_option_set
        @option_set ||= {
          "#{NS_WSMAN_DMTF}:OptionSet" => {
            "#{NS_WSMAN_DMTF}:Option" => [consolemode, skipcmd],
            :attributes! => {
              "#{NS_WSMAN_DMTF}:Option" => {
                'Name' => %w(WINRS_CONSOLEMODE_STDIN WINRS_SKIP_CMD_SHELL)
              }
            }
          }
        }
      end

      private

      def codepage
        # utf8 as default codepage (from https://msdn.microsoft.com/en-us/library/dd317756(VS.85).aspx)
        @codepage ||= options[:codepage] || 65_001
      end

      def noprofile
        @noprofile ||= options[:noprofile] || 'FALSE'
      end

      def consolemode
        @consolemode ||= options[:console_mode_stdin] || 'TRUE'
      end

      def skipcmd
        @skipcmd ||= options[:skip_cmd_shell] || 'FALSE'
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
