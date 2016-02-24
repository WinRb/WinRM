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

require_relative 'core/connection_configuration'
require_relative 'http/transport_factory'
require_relative 'shells/shell_factory'

module WinRM
  class Connection

    def initialize(connection_opts)
      configure_connection_opts(connection_opts)
      configure_logger
      create_shell_factory
    end

    def shell(shell_type)
      @shell_factory.create_shell(shell_type)
    end

    private

    def configure_connection_opts(connection_opts)
      @connection_opts = WinRM::Core::ConnectionConfiguration.create_with_defaults(connection_opts)
    end

    def configure_logger
      @logger = Logging.logger[self]
      @logger.level = :warn
      @logger.add_appenders(Logging.appenders.stdout)
    end

    def create_shell_factory
      transport_factory = WinRM::HTTP::TransportFactory.new
      transport = transport_factory.create_transport(@connection_opts)
      @shell_factory = WinRM::Shells::ShellFactory.new(@connection_opts, transport, @logger)
    end
  end
end
