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
    # WSMV message to create a remote shell
    class CreateShell
      include WinRM::WSMV::SOAP
      include WinRM::WSMV::Header

      # utf8 as default codepage
      # https://msdn.microsoft.com/en-us/library/dd317756(VS.85).aspx
      UTF8_CODE_PAGE = 65001

      attr_accessor :i_stream, :o_stream, :codepage, :noprofile
      attr_accessor :working_directory, :idle_timeout, :env_vars

      def initialize(session_opts, shell_opts = {})
        @session_opts = session_opts
        @shell_uri = opt_or_default(shell_opts, :shell_uri, RESOURCE_URI_CMD)
        @i_stream = opt_or_default(shell_opts, :i_stream, 'stdin')
        @o_stream = opt_or_default(shell_opts, :o_stream, 'stdout stderr')
        @codepage = opt_or_default(shell_opts, :codepage, UTF8_CODE_PAGE)
        @noprofile = opt_or_default(shell_opts, :noprofile, 'FALSE')
        @working_directory = opt_or_default(shell_opts, :working_directory)
        @idle_timeout = opt_or_default(shell_opts, :idle_timeout)
        @env_vars = opt_or_default(shell_opts, :env_vars)
      end

      def build
        builder = Builder::XmlMarkup.new
        builder.instruct!(:xml, encoding: 'UTF-8')
        builder.tag! :env, :Envelope, namespaces do |env|
          env.tag!(:env, :Header) do |h|
            h << Gyoku.xml(shell_headers)
          end
          env.tag! :env, :Body do |body|
            body.tag!("#{NS_WIN_SHELL}:Shell") { |s| s << Gyoku.xml(shell_body) }
          end
        end
      end

      private

      def opt_or_default(shell_opts, key, default_value = nil)
        shell_opts.key?(key) ? shell_opts[key] : default_value
      end

      def shell_body
        body = {
          "#{NS_WIN_SHELL}:InputStreams" => @i_stream,
          "#{NS_WIN_SHELL}:OutputStreams" => @o_stream
        }
        body["#{NS_WIN_SHELL}:WorkingDirectory"] = @working_directory if @working_directory
        if @idle_timeout
          body["#{NS_WIN_SHELL}:IdleTimeOut"] = format_idle_timeout(@idle_timeout)
        end
        body["#{NS_WIN_SHELL}:Environment"] = environment_vars_body if @env_vars
        body
      end

      # backwards compat - idle_timeout as an Iso8601Duration string
      def format_idle_timeout(timeout)
        timeout.is_a?(String) ? timeout : Iso8601Duration.sec_to_dur(timeout)
      end

      def environment_vars_body
        {
          "#{NS_WIN_SHELL}:Variable" => @env_vars.values,
          :attributes! => {
            "#{NS_WIN_SHELL}:Variable" => {
              'Name' => @env_vars.keys
            }
          }
        }
      end

      def shell_headers
        merge_headers(shared_headers(@session_opts), shell_resource_uri, action_create, header_opts)
      end

      def shell_resource_uri
        {
          "#{NS_WSMAN_DMTF}:ResourceURI" => @shell_uri,
          :attributes! => {
            "#{NS_WSMAN_DMTF}:ResourceURI" => {
              'mustUnderstand' => true
            }
          }
        }
      end

      def action_create
        {
          "#{NS_ADDRESSING}:Action" => 'http://schemas.xmlsoap.org/ws/2004/09/transfer/Create',
          :attributes! => {
            "#{NS_ADDRESSING}:Action" => {
              'mustUnderstand' => true
            }
          }
        }
      end

      def header_opts
        {
          "#{NS_WSMAN_DMTF}:OptionSet" => {
            "#{NS_WSMAN_DMTF}:Option" => [@noprofile, @codepage], :attributes! => {
              "#{NS_WSMAN_DMTF}:Option" => {
                'Name' => %w(WINRS_NOPROFILE WINRS_CODEPAGE)
              }
            }
          }
        }
      end
    end
  end
end
