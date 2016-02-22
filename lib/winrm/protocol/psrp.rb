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
    # Constructs MS-WSMV protocol SOAP messages for PSRP messages
    class PSRP < Base
      def open
        super
        keep_alive(shell_id)
        shell_id
      end

      def run_command(shell_id, command)
        command_id = SecureRandom.uuid.to_s.upcase
        pipline = PSRP::MessageFactory.create_pipeline_message(3, shell_id, command_id, command)

        cmd_envelope = write_envelope(action_command, nil, shell_id) do |env_body|
          env_body.tag!(
            "#{NS_WIN_SHELL}:CommandLine",
            'CommandId' => command_id
          ) do |s|
            s << Gyoku.xml(
              "#{NS_WIN_SHELL}:Command" => 'Invoke-Expression',
              "#{NS_WIN_SHELL}:Arguments" => encode_bytes(pipline.bytes)
            )
          end
        end

        REXML::XPath.first(
          transport.send_request(cmd_envelope.target!),
          "//#{NS_WIN_SHELL}:CommandId"
        ).text
      end

      def shell_body
        session_capabilities = WinRM::PSRP::MessageFactory.session_capability_message(1, shell_id)
        runspace_init = WinRM::PSRP::MessageFactory.init_runspace_pool_message(1, shell_id)
        body = shell_body_streams
        body['creationXml'] = encode_bytes(session_capabilities.bytes + runspace_init.bytes)
        body[:attributes!] = {
          'creationXml' => {
            'xmlns' => 'http://schemas.microsoft.com/powershell'
          }
        }
        body
      end

      protected

      def shell_envelope
        write_envelope(action_create, create_option_set) do |body|
          body.tag!(
            "#{NS_WIN_SHELL}:Shell",
            'ShellId' => shell_id
          ) { |s| s << Gyoku.xml(shell_body) }
        end
      end

      def resource_uri
        { "#{NS_WSMAN_DMTF}:ResourceURI" => 'http://schemas.microsoft.com/powershell/Microsoft.PowerShell',
          :attributes! => { "#{NS_WSMAN_DMTF}:ResourceURI" => { 'mustUnderstand' => true } } }
      end

      def input_streams
        %w(stdin pr)
      end

      def output_streams
        ['stdout']
      end

      private

      def keep_alive(shell_id)
        opts = {
          "#{NS_WSMAN_DMTF}:OptionSet" => {
            "#{NS_WSMAN_DMTF}:Option" => 'TRUE',
            :attributes! => {
              "#{NS_WSMAN_DMTF}:Option" => {
                'Name' => 'WSMAN_CMDSHELL_OPTION_KEEPALIVE'
              }
            }
          }
        }
        keep_alive_body = { "#{NS_WIN_SHELL}:DesiredStream" => 'stdout' }

        write_envelope(action_receive, opts, shell_id) do |body|
          body.tag!("#{NS_WIN_SHELL}:Receive") { |cl| cl << Gyoku.xml(keep_alive_body) }
        end

        transport.send_request(builder.target!)
      end

      def shell_id
        @shell_id ||= SecureRandom.uuid.to_s.upcase
      end

      def create_option_set
        @option_set ||= {
          "#{NS_WSMAN_DMTF}:OptionSet" => {
            "#{NS_WSMAN_DMTF}:Option" => 2.3,
            :attributes! => {
              "#{NS_WSMAN_DMTF}:Option" => {
                'Name' => 'protocolversion',
                'MustComply' => 'true'
              }
            }
          },
          :attributes! => {
            "#{NS_WSMAN_DMTF}:OptionSet" => {
              'env:mustUnderstand' => 'true'
            }
          }
        }
      end

      def encode_bytes(bytes)
        Base64.strict_encode64(bytes.pack('C*'))
      end
    end
  end
end
