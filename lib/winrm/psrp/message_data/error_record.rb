# -*- encoding: utf-8 -*-
#
# Copyright 2016 Matt Wrock <matt@mattwrock.com>
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
  module PSRP
    module MessageData
      # pipeline host call message type
      class ErrorRecord < Base
        def exception
          @exception ||= begin
            ex_props = REXML::XPath.first(REXML::Document.new(raw), "//*[@N='Exception']/Props")
            ex_props.elements.each_with_object({}) do |node, props|
              props[node.attributes['N'].downcase.to_sym] = node.text if node.text
            end
          end
        end

        def fully_qualified_error_id
          @fully_qualified_error_id ||= begin
            REXML::XPath.first(REXML::Document.new(raw), "//*[@N='FullyQualifiedErrorId']").text
          end
        end

        def invocation_info
          @invocation_info ||= begin
            in_props = REXML::XPath.first(doc, "//*[@N='InvocationInfo']/Props")
            in_props.elements.each_with_object({}) do |node, props|
              props[node.attributes['N'].downcase.to_sym] = node.text if node.text
            end
          end
        end

        def error_category_message
          @error_category_message ||= begin
            message = REXML::XPath.first(doc, "//*[@N='ErrorCategory_Message']")
            message.text if message
          end
        end

        def error_details_script_stack_trace
          @error_details_script_stack_trace ||= begin
            trace = REXML::XPath.first(doc, "//*[@N='ErrorDetails_ScriptStackTrace']")
            trace.text if trace
          end
        end

        def doc
          @doc ||= REXML::Document.new(raw)
        end
      end
    end
  end
end
