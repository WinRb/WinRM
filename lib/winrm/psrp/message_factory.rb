# encoding: UTF-8
#
# Copyright 2016 Shawn Neal <sneal@sneal.net>
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

require 'erubis'

module WinRM
  module PSRP
    class MessageFactory
      class << self
        # Creates a new session capability PSRP message.
        # @param id [Fixnum] The incrementing fragment id.
        # @param shell_id [String] The UUID of the remote shell/runspace pool.
        def session_capability_message(id, shell_id)
          Message.new(id, shell_id, nil, 0x00010002, render('session_capability'))
        end

        # Creates a new init runspace pool PSRP message.
        # @param id [Fixnum] The incrementing fragment id.
        # @param shell_id [String] The UUID of the remote shell/runspace pool.
        def init_runspace_pool_message(id, shell_id)
          Message.new(id, shell_id, nil, 0x00010004, render('init_runspace_pool'))
        end

        # Creates a new PSRP message that creates pipline to execute a command.
        # @param id [Fixnum] The incrementing fragment id.
        # @param shell_id [String] The UUID of the remote shell/runspace pool.
        # @param command_id [String] The UUID to correlate the command/pipeline
        # response.
        # @param command [String] The command passed to Invoke-Expression.
        def create_pipeline_message(id, shell_id, command_id, command)
          Message.new(id, shell_id, command_id, 0x00021006, render('create_pipeline', command: command))
        end

        # Renders the specified template with the given context
        # @param template [String] The base filename of the PSRP message template.
        # @param context [Hash] Any options required for rendering the template.
        # @return [String] The rendered XML PSRP message.
        # @api private
        def render(template, context = nil)
          template_path = File.expand_path(
            "#{File.dirname(__FILE__)}/#{template}.xml.erb")
          template = File.read(template_path)
          Erubis::Eruby.new(template).result(context)
        end
      end
    end
  end
end
