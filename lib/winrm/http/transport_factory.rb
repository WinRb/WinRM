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

require_relative 'transport'

module WinRM
  module HTTP
    class TransportFactory
      def create_transport(connection_opts)
        transport = connection_opts[:transport]
      #  begin
          send "init_#{transport}_transport", connection_opts
        #rescue NoMethodError => e
      #    fail "Invalid transport '#{transport}' specified, expected: negotiate, kerberos, plaintext, ssl."
      #  end
      end

      private

      def init_negotiate_transport(opts)
        HTTP::HttpNegotiate.new(opts[:endpoint], opts[:user], opts[:password], opts)
      end

      def init_kerberos_transport(opts)
        require 'gssapi'
        require 'gssapi/extensions'
        HTTP::HttpGSSAPI.new(opts[:endpoint], opts[:realm], opts[:service], opts[:keytab], opts)
      end

      def init_plaintext_transport(opts)
        HTTP::HttpPlaintext.new(opts[:endpoint], opts[:user], opts[:password], opts)
      end

      def init_ssl_transport(opts)
        if opts[:basic_auth_only]
          HTTP::BasicAuthSSL.new(opts[:endpoint], opts[:user], opts[:password], opts)
        else
          HTTP::HttpNegotiate.new(opts[:endpoint], opts[:user], opts[:password], opts)
        end
      end
    end
  end
end
