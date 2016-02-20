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

require_relative 'soap'
require_relative 'header'

module WinRM
  module WSMV
    # WSMV message to execute a command inside a remote shell
    class Command
      include WinRM::WSMV::SOAP
      include WinRM::WSMV::Header

      def initialize(session_opts, shell_id, shell_uri, command_id, command, arguments = [], cmd_opts = {})
        @session_opts = session_opts
        @command_id = command_id
        @shell_id = shell_id
        @shell_uri = shell_uri
        @command = command
        @arguments = arguments
        @consolemode = cmd_opts.key?(:console_mode_stdin) ? cmd_opts[:console_mode_stdin] : 'TRUE'
        @skipcmd = cmd_opts.key?(:skip_cmd_shell) ? cmd_opts[:skip_cmd_shell] : 'FALSE'
      end

      def build
        builder = Builder::XmlMarkup.new
        builder.instruct!(:xml, encoding: 'UTF-8')
        builder.tag! :env, :Envelope, namespaces do |env|
          env.tag!(:env, :Header) { |h| h << Gyoku.xml(command_headers) }
          env.tag!(:env, :Body) do |env_body|
            env_body.tag!("#{NS_WIN_SHELL}:CommandLine", 'CommandId' => @command_id) do |cl|
              cl << Gyoku.xml(command_body)
            end
          end
        end
        issue69_unescape_single_quotes(builder.target!)
      end

      private

      def issue69_unescape_single_quotes(xml)
        escaped_cmd = /<#{NS_WIN_SHELL}:Command>(.+)<\/#{NS_WIN_SHELL}:Command>/m.match(xml)[1]
        xml[escaped_cmd] = escaped_cmd.gsub(/&#39;/, "'")
        xml
      end

      def command_body
        {
          "#{NS_WIN_SHELL}:Command" => "\"#{@command}\"", "#{NS_WIN_SHELL}:Arguments" => @arguments
        }
      end

      def command_headers
        merge_headers(shared_headers(@session_opts),
                      resource_uri_shell(@shell_uri),
                      action_command,
                      command_header_opts,
                      selector_shell_id(@shell_id))
      end

      def command_header_opts
        return {} if @shell_uri != RESOURCE_URI_CMD
        # this is only needed for the regular Windows shell
        {
          "#{NS_WSMAN_DMTF}:OptionSet" => {
            "#{NS_WSMAN_DMTF}:Option" => [@consolemode, @skipcmd], :attributes! => {
              "#{NS_WSMAN_DMTF}:Option" => {
                'Name' => %w(WINRS_CONSOLEMODE_STDIN WINRS_SKIP_CMD_SHELL)
              }
            }
          }
        }
      end
    end
  end
end
