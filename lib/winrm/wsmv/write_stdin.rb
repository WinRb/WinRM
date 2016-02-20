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

require 'base64'
require_relative 'soap'
require_relative 'header'

module WinRM
  module WSMV
    # WSMV message to send stdin to a remote shell
    class WriteStdin
      include WinRM::WSMV::SOAP
      include WinRM::WSMV::Header

      def initialize(session_opts, stdin_opts)
        validate_opts(session_opts, stdin_opts)
        init_ops(session_opts, stdin_opts)
      end

      def build
        # Signal the Command references to terminate (close stdout/stderr)
        builder = Builder::XmlMarkup.new
        builder.instruct!(:xml, encoding: 'UTF-8')
        builder.tag! :env, :Envelope, namespaces do |env|
          env.tag!(:env, :Header) { |h| h << Gyoku.xml(stdin_headers) }
          env.tag!(:env, :Body) do |env_body|
            env_body << Gyoku.xml(stdin_body)
          end
        end
      end

      private

      def init_ops(session_opts, stdin_opts)
        @session_opts = session_opts
        @shell_id = stdin_opts[:shell_id]
        @command_id = stdin_opts[:command_id]
        @stdin = stdin_opts[:stdin]
        @shell_uri = stdin_opts[:shell_uri] || RESOURCE_URI_CMD
      end

      def validate_opts(session_opts, stdin_opts)
        fail 'session_opts is required' unless session_opts
        fail 'stdin_opts[:shell_id] is required' unless stdin_opts[:shell_id]
        fail 'stdin_opts[:command_id] is required' unless stdin_opts[:command_id]
        fail 'stdin_opts[:stdin] is required' unless stdin_opts[:stdin]
      end

      def stdin_headers
        merge_headers(shared_headers(@session_opts),
                      resource_uri_shell(@shell_uri),
                      action_send,
                      selector_shell_id(@shell_id))
      end

      def action_send
        {
          "#{NS_ADDRESSING}:Action" =>
          'http://schemas.microsoft.com/wbem/wsman/1/windows/shell/Send',
          :attributes! => {
            "#{NS_ADDRESSING}:Action" => {
              'mustUnderstand' => true
            }
          }
        }
      end

      def stdin_body
        {
          "#{NS_WIN_SHELL}:Send" => {
            "#{NS_WIN_SHELL}:Stream" => {
              '@Name' => 'stdin',
              '@CommandId' => @command_id,
              :content! => Base64.encode64(@stdin)
            }
          }
        }
      end
    end
  end
end
