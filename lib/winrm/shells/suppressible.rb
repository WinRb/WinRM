# -*- encoding: utf-8 -*-
#
# Copyright 2017 Matt Wrock <matt@mattwrock.com>
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

require_relative '../exceptions'

module WinRM
  module Shells
    # Shell mixin for suppressing a network exception
    module Suppressible
      # performs an operation and suppresses any network exceptions
      def suppressible
        yield
      rescue *WinRM::NETWORK_EXCEPTIONS.call => e
        logger.info("[WinRM] Exception suppressed: #{e.message}")
      end
    end
  end
end
