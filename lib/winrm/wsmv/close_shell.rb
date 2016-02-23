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
    # WSMV message to close a remote shell
    class CloseShell
      include WinRM::WSMV::SOAP
      include WinRM::WSMV::Header

      def initialize(session_opts, shell_opts)
        fail 'shell_opts[:shell_id] is required' unless shell_opts[:shell_id]
        @session_opts = session_opts
        @shell_id = shell_opts[:shell_id]
        @shell_uri = shell_opts[:shell_uri] || RESOURCE_URI_CMD
      end

      def build
        builder = Builder::XmlMarkup.new
        builder.instruct!(:xml, :encoding => 'UTF-8')
        builder.tag!('env:Envelope', namespaces) do |env|
          env.tag!('env:Header') { |h| h << Gyoku.xml(close_header) }
          env.tag!('env:Body')
        end
      end

      private

      def close_header
        merge_headers(shared_headers(@session_opts),
                      resource_uri_shell(@shell_uri),
                      action_delete,
                      selector_shell_id(@shell_id))
      end
    end
  end
end
