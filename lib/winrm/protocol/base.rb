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
  module Protocol
    # Constructs MS-WSMV protocol SOAP messages
    class Base
      def initialize(transport, options)
        @transport = transport
        @logger = options[:logger]
        @options = options
      end

      attr_reader :options, :logger, :transport

      def open
        logger.debug("[WinRM] opening remote shell on #{transport.endpoint}")

        resp_doc = transport.send_request(shell_envelope.target!)
        shell_id = REXML::XPath.first(resp_doc, "//*[@Name='ShellId']").text
        logger.debug("[WinRM] remote shell #{shell_id} is open on #{transport.endpoint}")

        shell_id
      end

      def close(shell_id)
        logger.debug("[WinRM] closing remote shell #{shell_id} on #{transport.endpoint}")

        envelope = write_envelope(action_delete, nil, shell_id)
        transport.send_request(envelope.target!)

        logger.debug("[WinRM] remote shell #{shell_id} closed")
        true
      end

      def run_command(_shell_id, _command, _arguments = [])
        fail NotImplementedError
      end

      def resource_uri
        fail NotImplementedError
      end

      def input_streams
        fail NotImplementedError
      end

      def output_streams
        fail NotImplementedError
      end

      protected

      def write_envelope(action, option_set, shell_id = nil)
        headers = [header, resource_uri, action, option_set]
        headers << selector_shell_id(shell_id) if shell_id
        builder = Builder::XmlMarkup.new
        builder.instruct!(:xml, encoding: 'UTF-8')
        builder.tag! :env, :Envelope, namespaces do |env|
          env.tag!(:env, :Header) { |h| h << Gyoku.xml(merge_headers(*headers)) }
          env.tag!(:env, :Body) { |body| yield body if block_given? }
        end

        builder
      end

      def shell_envelope
        write_envelope(action_create, create_option_set) do |body|
          body.tag!("#{NS_WIN_SHELL}:Shell") { |s| s << Gyoku.xml(shell_body) }
        end
      end

      def shell_body_streams
        {
          "#{NS_WIN_SHELL}:InputStreams" => input_streams.join(' '),
          "#{NS_WIN_SHELL}:OutputStreams" => output_streams.join(' ')
        }
      end

      def namespaces
        {
          'xmlns:xsd' => 'http://www.w3.org/2001/XMLSchema',
          'xmlns:xsi' => 'http://www.w3.org/2001/XMLSchema-instance',
          'xmlns:env' => 'http://www.w3.org/2003/05/soap-envelope',
          'xmlns:a' => 'http://schemas.xmlsoap.org/ws/2004/08/addressing',
          'xmlns:b' => 'http://schemas.dmtf.org/wbem/wsman/1/cimbinding.xsd',
          'xmlns:n' => 'http://schemas.xmlsoap.org/ws/2004/09/enumeration',
          'xmlns:x' => 'http://schemas.xmlsoap.org/ws/2004/09/transfer',
          'xmlns:w' => 'http://schemas.dmtf.org/wbem/wsman/1/wsman.xsd',
          'xmlns:p' => 'http://schemas.microsoft.com/wbem/wsman/1/wsman.xsd',
          'xmlns:rsp' => 'http://schemas.microsoft.com/wbem/wsman/1/windows/shell',
          'xmlns:cfg' => 'http://schemas.microsoft.com/wbem/wsman/1/config'
        }
      end

      def header
        {
          "#{NS_ADDRESSING}:To" => transport.endpoint.to_s,
          "#{NS_ADDRESSING}:ReplyTo" => {
            "#{NS_ADDRESSING}:Address" => 'http://schemas.xmlsoap.org/ws/2004/08/addressing/role/anonymous',
            attributes!: { "#{NS_ADDRESSING}:Address" => { 'mustUnderstand' => true } }
          },
          "#{NS_WSMAN_DMTF}:MaxEnvelopeSize" => options[:max_envelope_size],
          "#{NS_ADDRESSING}:MessageID" => "uuid:#{SecureRandom.uuid.to_s.upcase}",
          "#{NS_WSMAN_MSFT}:SessionId" => "uuid:#{session_id}",
          "#{NS_WSMAN_DMTF}:Locale/" => '',
          "#{NS_WSMAN_MSFT}:DataLocale/" => '',
          "#{NS_WSMAN_DMTF}:OperationTimeout" => options[:timeout],
          attributes!: {
            "#{NS_WSMAN_DMTF}:MaxEnvelopeSize" => { 'mustUnderstand' => true },
            "#{NS_WSMAN_DMTF}:Locale/" => locale_attributes,
            "#{NS_WSMAN_MSFT}:DataLocale/" => locale_attributes,
            "#{NS_WSMAN_MSFT}:SessionId" => { 'mustUnderstand' => false }
          }
        }
      end

      def locale_attributes
        { 'xml:lang' => options[:locale], 'mustUnderstand' => false }
      end

      def action_create
        {
          "#{NS_ADDRESSING}:Action" => 'http://schemas.xmlsoap.org/ws/2004/09/transfer/Create',
          attributes!: { "#{NS_ADDRESSING}:Action" => { 'mustUnderstand' => true } }
        }
      end

      def action_command
        {
          "#{NS_ADDRESSING}:Action" => 'http://schemas.microsoft.com/wbem/wsman/1/windows/shell/Command',
          attributes!: { "#{NS_ADDRESSING}:Action" => { 'mustUnderstand' => true } } }
      end

      def action_delete
        {
          "#{NS_ADDRESSING}:Action" => 'http://schemas.xmlsoap.org/ws/2004/09/transfer/Delete',
          attributes!: { "#{NS_ADDRESSING}:Action" => { 'mustUnderstand' => true } }
        }
      end

      def session_id
        @session_id ||= SecureRandom.uuid.to_s.upcase
      end

      def selector_shell_id(shell_id)
        {
          "#{NS_WSMAN_DMTF}:SelectorSet" => {
            "#{NS_WSMAN_DMTF}:Selector" => shell_id,
            attributes!: { "#{NS_WSMAN_DMTF}:Selector" => { 'Name' => 'ShellId' } }
          }
        }
      end

      # merge the various header hashes and make sure we carry all of the attributes
      #   through instead of overwriting them.
      def merge_headers(*headers)
        headers.each_with_object({}) do |h, o|
          next if h.nil?
          o.merge!(h) { |k, v1, v2| v1.merge!(v2) if k == :attributes! }
        end
      end
    end
  end
end
