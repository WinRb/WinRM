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
    # WSMV message to query Windows via WQL
    class WqlQuery
      include WinRM::WSMV::SOAP
      include WinRM::WSMV::Header

      def initialize(session_opts, wql)
        @session_opts = session_opts
        @wql = wql
      end

      def build
        builder = Builder::XmlMarkup.new
        builder.instruct!(:xml, :encoding => 'UTF-8')
        builder.tag! :env, :Envelope, namespaces do |env|
          env.tag!(:env, :Header) { |h| h << Gyoku.xml(wql_header) }
          env.tag!(:env, :Body) do |env_body|
            env_body.tag!("#{NS_ENUM}:Enumerate") { |en| en << Gyoku.xml(wql_body) }
          end
        end
      end

      private

      def wql_header
        merge_headers(shared_headers(@session_opts), resource_uri_wmi, action_enumerate)
      end

      def wql_body
        {
          "#{NS_WSMAN_DMTF}:OptimizeEnumeration" => nil,
          "#{NS_WSMAN_DMTF}:MaxElements" => '32000',
          "#{NS_WSMAN_DMTF}:Filter" => @wql,
          "#{NS_WSMAN_MSFT}:SessionId" => "uuid:#{@session_opts[:session_id]}",
          :attributes! => {
            "#{NS_WSMAN_DMTF}:Filter" => {
              'Dialect' => 'http://schemas.microsoft.com/wbem/wsman/1/WQL'
            }
          }
        }
      end

    end
  end
end
