# -*- encoding: utf-8 -*-
#
# Copyright 2016 Shawn Neal <sneal@sneal.net>
# Copyright 2015 Matt Wrock <matt@mattwrock.com>
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

require_relative '../exceptions/exceptions'

module WinRM
  module Core
    module Retryable
      RETRYABLE_EXCEPTIONS = lambda do
        [
          Errno::EACCES, Errno::EADDRINUSE, Errno::ECONNREFUSED, Errno::ETIMEDOUT,
          Errno::ECONNRESET, Errno::ENETUNREACH, Errno::EHOSTUNREACH,
          ::WinRM::WinRMHTTPTransportError, ::WinRM::WinRMAuthorizationError,
          HTTPClient::KeepAliveDisconnected, HTTPClient::ConnectTimeoutError
        ].freeze
      end

      def retryable(retries, delay)
        yield
      rescue *RETRYABLE_EXCEPTIONS.call => e
        if (retries -= 1) > 0
          sleep(delay)
          retry
        else
          raise
        end
      end
    end
  end
end
