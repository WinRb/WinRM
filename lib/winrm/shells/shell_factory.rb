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

module WinRM
  module Shells
    class ShellFactory
      def initialize(connection_opts)
        @connection_opts = connection_opts
      end

      def create_shell(shell_type)
        case shell_type
        when :cmd
          return WinRM::Shells::Cmd.new()
        when :powershell
          return WinRM::Shells::PowerShell.new()
        else
          fail "#{shell_type} is not a valid WinRM shell type. " \
            'Expected either :cmd or :powershell.'
        end
      end
    end
  end
end
