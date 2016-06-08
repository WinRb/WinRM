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

require 'securerandom'
require_relative 'base'
require_relative '../psrp/message_defragmenter'
require_relative '../psrp/message_fragmenter'
require_relative '../psrp/powershell_output_processor'
require_relative '../wsmv/configuration'
require_relative '../wsmv/create_pipeline'
require_relative '../wsmv/send_data'
require_relative '../wsmv/init_runspace_pool'
require_relative '../wsmv/keep_alive'

module WinRM
  module Shells
    # Proxy to a remote PowerShell instance
    class PowerShell < Base
      include WinRM::WSMV::ResponseStreamReader

      class << self
        def finalize(connection_opts, transport, shell_id)
          proc { PowerShell.close_shell(connection_opts, transport, shell_id) }
        end

        def close_shell(connection_opts, transport, shell_id)
          msg = WinRM::WSMV::CloseShell.new(
            connection_opts,
            shell_id: shell_id,
            shell_uri: WinRM::WSMV::Header::RESOURCE_URI_POWERSHELL
          )
          transport.send_request(msg.build)
        end
      end

      # Create a new powershell shell
      # @param connection_opts [ConnectionOpts] The WinRM connection options
      # @param transport [HttpTransport] The WinRM SOAP transport
      # @param logger [Logger] The logger to log diagnostic messages to
      def initialize(connection_opts, transport, logger)
        super
        @fragmenter = WinRM::PSRP::MessageFragmenter.new
        @shell_uri = WinRM::WSMV::Header::RESOURCE_URI_POWERSHELL
      end

      protected

      def output_processor
        WinRM::PSRP::PowershellOutputProcessor.new(
          connection_opts,
          transport,
          logger,
          shell_uri: shell_uri,
          out_streams: %w(stdout)
        )
      end

      def send_command(command, _arguments)
        command_id = SecureRandom.uuid.to_s.upcase
        message = PSRP::MessageFactory.create_pipeline_message(shell_id, command_id, command)
        @fragmenter.fragment(message) do |fragment|
          command_args = [connection_opts, shell_id, command_id, fragment]
          if fragment.start_fragment
            transport.send_request(WinRM::WSMV::CreatePipeline.new(*command_args).build)
          else
            transport.send_request(WinRM::WSMV::SendData.new(*command_args).build)
          end
        end
        logger.debug("[WinRM] Command created for #{command} with id: #{command_id}")
        command_id
      end

      def open_shell
        shell_id = SecureRandom.uuid.to_s.upcase
        runspace_msg = WinRM::WSMV::InitRunspacePool.new(
          connection_opts,
          shell_id,
          open_shell_payload(shell_id)
        )
        resp_doc = transport.send_request(runspace_msg.build)
        shell_id = REXML::XPath.first(resp_doc, "//*[@Name='ShellId']").text
        wait_for_running(shell_id)
        shell_id
      end

      private

      def max_envelope_size_kb
        @max_envelope_size_kb ||= begin
          config_msg = WinRM::WSMV::Configuration.new(connection_opts)
          resp_doc = transport.send_request(config_msg.build)
          REXML::XPath.first(resp_doc, "//#{NS_WSMAN_CONF}:MaxEnvelopeSizekb").text.to_i
        end
      end

      def open_shell_payload(shell_id)
        [
          WinRM::PSRP::MessageFactory.session_capability_message(shell_id),
          WinRM::PSRP::MessageFactory.init_runspace_pool_message(shell_id)
        ].map do |message|
          @fragmenter.fragment(message).bytes
        end.flatten
      end

      def wait_for_running(shell_id)
        state = ''
        keepalive_msg = WinRM::WSMV::KeepAlive.new(connection_opts, shell_id)

        # 2 is "openned". if we start issuing commands while in "openning" the runspace
        # seems to hang
        until state.include?('<I32 N="RunspaceState">2</I32>')
          doc = transport.send_request(keepalive_msg.build)
          read_streams(doc) do |stream|
            message = WinRM::PSRP::MessageDefragmenter.new.defragment(stream[:text])
            logger.debug("[WinRM] polling for pipeline state. message: #{message.inspect}")
            state = message.data
          end
        end
      end
    end
  end
end
