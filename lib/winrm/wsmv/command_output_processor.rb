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
    class CommandOutputProcessor
      include WinRM::WSMV::SOAP
      include WinRM::WSMV::Header

      def initialize(connection_opts, transport, out_opts = {})
        @connection_opts = connection_opts
        @transport = transport
        @out_opts = out_opts
      end

      def command_output(shell_id, command_id, &block)
        cmd_out_opts = {
          shell_id: shell_id,
          command_id: command_id
        }.merge(@out_opts)

        resp_doc = nil
        request_msg = WinRM::WSMV::CommandOutput.new(@connection_opts, cmd_out_opts).build
        done_elems = []
        output = Output.new

        while done_elems.empty?
          resp_doc = send_get_output_message(request_msg)

          REXML::XPath.match(resp_doc, "//#{NS_WIN_SHELL}:Stream").each do |n|
            next if n.text.nil? || n.text.empty?

            # decode and replace invalid unicode characters
            decoded_text = Base64.decode64(n.text).force_encoding('utf-8')
            if ! decoded_text.valid_encoding?
              if decoded_text.respond_to?(:scrub!)
                decoded_text.scrub!
              else
                decoded_text = decoded_text.encode('utf-16', invalid: :replace, undef: :replace)
                  .encode('utf-8')
              end
            end

            # remove BOM which 2008R2 applies
            stream = { n.attributes['Name'].to_sym => decoded_text.sub('\xEF\xBB\xBF', '') }
            output[:data] << stream
            yield stream[:stdout], stream[:stderr] if block_given?
          end

          # We may need to get additional output if the stream has not finished.
          done_elems = REXML::XPath.match(resp_doc, "//*[@State='http://schemas.microsoft.com/wbem/wsman/1/windows/shell/CommandState/Done']")
        end

        output[:exitcode] = REXML::XPath.first(resp_doc, "//#{NS_WIN_SHELL}:ExitCode").text.to_i
        output
      end

      private

      def send_get_output_message(message)
        @transport.send_request(message)
      rescue WinRMWSManFault => e
        # If no output is available before the wsman:OperationTimeout expires,
        # the server MUST return a WSManFault with the Code attribute equal to
        # 2150858793. When the client receives this fault, it SHOULD issue
        # another Receive request.
        # http://msdn.microsoft.com/en-us/library/cc251676.aspx
        if e.fault_code == '2150858793'
          #logger.debug("[WinRM] retrying receive request after timeout")
          retry
        else
          raise
        end
      end
    end
  end
end
