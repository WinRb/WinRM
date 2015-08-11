# encoding: UTF-8
#
# Copyright 2010 Dan Wanek <dan.wanek@gmail.com>
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

require_relative 'response_handler'

module WinRM
  module HTTP
    # A generic HTTP transport that utilized HTTPClient to send messages back and forth.
    # This backend will maintain state for every WinRMWebService instance that is instantiated so it
    # is possible to use GSSAPI with Keep-Alive.
    class HttpTransport
      # Set this to an unreasonable amount because WinRM has its own timeouts
      DEFAULT_RECEIVE_TIMEOUT = 3600

      attr_reader :endpoint

      def initialize(endpoint)
        @endpoint = endpoint.is_a?(String) ? URI.parse(endpoint) : endpoint
        @httpcli = HTTPClient.new(agent_name: 'Ruby WinRM Client')
        @httpcli.receive_timeout = DEFAULT_RECEIVE_TIMEOUT
        @logger = Logging.logger[self]
      end

      # Sends the SOAP payload to the WinRM service and returns the service's
      # SOAP response. If an error occurrs an appropriate error is raised.
      #
      # @param [String] The XML SOAP message
      # @returns [REXML::Document] The parsed response body
      def send_request(message)
        log_soap_message(message)
        hdr = {
          'Content-Type' => 'application/soap+xml;charset=UTF-8',
          'Content-Length' => message.length }
        resp = @httpcli.post(@endpoint, message, hdr)
        log_soap_message(resp.http_body.content)
        handler = WinRM::ResponseHandler.new(resp.http_body.content, resp.status)
        handler.parse_to_xml
      end

      # We'll need this to force basic authentication if desired
      def basic_auth_only!
        auths = @httpcli.www_auth.instance_variable_get('@authenticator')
        auths.delete_if { |i| i.scheme !~ /basic/i }
      end

      # Disable SSPI Auth
      def no_sspi_auth!
        auths = @httpcli.www_auth.instance_variable_get('@authenticator')
        auths.delete_if { |i| i.is_a? HTTPClient::SSPINegotiateAuth }
      end

      # Disable SSL Peer Verification
      def no_ssl_peer_verification!
        @httpcli.ssl_config.verify_mode = OpenSSL::SSL::VERIFY_NONE
      end

      # HTTP Client receive timeout. How long should a remote call wait for a
      # for a response from WinRM?
      def receive_timeout=(sec)
        @httpcli.receive_timeout = sec
      end

      def receive_timeout
        @httpcli.receive_timeout
      end

      protected

      def log_soap_message(message)
        return unless @logger.debug?

        xml_msg = REXML::Document.new(message)
        formatter = REXML::Formatters::Pretty.new(2)
        formatter.compact = true
        formatter.write(xml_msg, @logger)
        @logger.debug("\n")
      rescue StandardError => e
        @logger.debug("Couldn't log SOAP request/response: #{e.message} - #{message}")
      end
    end

    # Plain text, insecure, HTTP transport
    class HttpPlaintext < HttpTransport
      def initialize(endpoint, user, pass, opts)
        super(endpoint)
        @httpcli.set_auth(nil, user, pass)
        no_sspi_auth! if opts[:disable_sspi]
        basic_auth_only! if opts[:basic_auth_only]
        no_ssl_peer_verification! if opts[:no_ssl_peer_verification]
      end
    end

    # Uses SSL to secure the transport
    class HttpSSL < HttpTransport
      def initialize(endpoint, user, pass, ca_trust_path = nil, opts)
        super(endpoint)
        @httpcli.set_auth(endpoint, user, pass)
        @httpcli.ssl_config.set_trust_ca(ca_trust_path) unless ca_trust_path.nil?
        no_sspi_auth! if opts[:disable_sspi]
        basic_auth_only! if opts[:basic_auth_only]
        no_ssl_peer_verification! if opts[:no_ssl_peer_verification]
      end
    end

    # Uses Kerberos/GSSAPI to authenticate and encrypt messages
    # rubocop:disable Metrics/ClassLength
    class HttpGSSAPI < HttpTransport
      # @param [String,URI] endpoint the WinRM webservice endpoint
      # @param [String] realm the Kerberos realm we are authenticating to
      # @param [String<optional>] service the service name, default is HTTP
      # @param [String<optional>] keytab the path to a keytab file if you are using one
      # rubocop:disable Lint/UnusedMethodArgument
      def initialize(endpoint, realm, service = nil, keytab = nil, opts)
        # rubocop:enable Lint/UnusedMethodArgument
        super(endpoint)
        # Remove the GSSAPI auth from HTTPClient because we are doing our own thing
        no_sspi_auth!
        service ||= 'HTTP'
        @service = "#{service}/#{@endpoint.host}@#{realm}"
        init_krb
      end

      # Sends the SOAP payload to the WinRM service and returns the service's
      # SOAP response. If an error occurrs an appropriate error is raised.
      #
      # @param [String] The XML SOAP message
      # @returns [REXML::Document] The parsed response body
      def send_request(message)
        resp = send_kerberos_request(message)

        if resp.status == 401
          @logger.debug 'Got 401 - reinitializing Kerberos and retrying one more time'
          init_krb
          resp = send_kerberos_request(message)
        end

        handler = WinRM::ResponseHandler.new(winrm_decrypt(resp.http_body.content), resp.status)
        handler.parse_to_xml
      end

      private

      # rubocop:disable Metrics/MethodLength
      # rubocop:disable Metrics/AbcSize

      # Sends the SOAP payload to the WinRM service and returns the service's
      # HTTP response.
      #
      # @param [String] The XML SOAP message
      # @returns [Object] The HTTP response object
      def send_kerberos_request(message)
        log_soap_message(message)
        original_length = message.length
        pad_len, emsg = winrm_encrypt(message)
        hdr = {
          'Connection' => 'Keep-Alive',
          'Content-Type' =>
            'multipart/encrypted;' \
            'protocol="application/HTTP-Kerberos-session-encrypted";' \
            'boundary="Encrypted Boundary"'
        }

        body = <<-EOF
--Encrypted Boundary\r
Content-Type: application/HTTP-Kerberos-session-encrypted\r
OriginalContent: type=application/soap+xml;charset=UTF-8;Length=#{original_length + pad_len}\r
--Encrypted Boundary\r
Content-Type: application/octet-stream\r
#{emsg}--Encrypted Boundary\r
        EOF

        resp = @httpcli.post(@endpoint, body, hdr)
        log_soap_message(resp.http_body.content)
        resp
      end

      def init_krb
        @logger.debug "Initializing Kerberos for #{@service}"
        @gsscli = GSSAPI::Simple.new(@endpoint.host, @service)
        token = @gsscli.init_context
        auth = Base64.strict_encode64 token

        hdr = {
          'Authorization' => "Kerberos #{auth}",
          'Connection' => 'Keep-Alive',
          'Content-Type' => 'application/soap+xml;charset=UTF-8'
        }
        @logger.debug 'Sending HTTP POST for Kerberos Authentication'
        r = @httpcli.post(@endpoint, '', hdr)
        itok = r.header['WWW-Authenticate'].pop
        itok = itok.split.last
        itok = Base64.strict_decode64(itok)
        @gsscli.init_context(itok)
      end

      # @return [String] the encrypted request string
      def winrm_encrypt(str)
        @logger.debug "Encrypting SOAP message:\n#{str}"
        iov_cnt = 3
        iov = FFI::MemoryPointer.new(GSSAPI::LibGSSAPI::GssIOVBufferDesc.size * iov_cnt)

        iov0 = GSSAPI::LibGSSAPI::GssIOVBufferDesc.new(FFI::Pointer.new(iov.address))
        iov0[:type] = (GSSAPI::LibGSSAPI::GSS_IOV_BUFFER_TYPE_HEADER | \
          GSSAPI::LibGSSAPI::GSS_IOV_BUFFER_FLAG_ALLOCATE)

        iov1 = GSSAPI::LibGSSAPI::GssIOVBufferDesc.new(
          FFI::Pointer.new(iov.address + (GSSAPI::LibGSSAPI::GssIOVBufferDesc.size * 1)))
        iov1[:type] = (GSSAPI::LibGSSAPI::GSS_IOV_BUFFER_TYPE_DATA)
        iov1[:buffer].value = str

        iov2 = GSSAPI::LibGSSAPI::GssIOVBufferDesc.new(
          FFI::Pointer.new(iov.address + (GSSAPI::LibGSSAPI::GssIOVBufferDesc.size * 2)))
        iov2[:type] = (GSSAPI::LibGSSAPI::GSS_IOV_BUFFER_TYPE_PADDING | \
          GSSAPI::LibGSSAPI::GSS_IOV_BUFFER_FLAG_ALLOCATE)

        conf_state = FFI::MemoryPointer.new :uint32
        min_stat = FFI::MemoryPointer.new :uint32

        GSSAPI::LibGSSAPI.gss_wrap_iov(
          min_stat,
          @gsscli.context,
          1,
          GSSAPI::LibGSSAPI::GSS_C_QOP_DEFAULT,
          conf_state,
          iov,
          iov_cnt)

        token = [iov0[:buffer].length].pack('L')
        token += iov0[:buffer].value
        token += iov1[:buffer].value
        pad_len = iov2[:buffer].length
        token += iov2[:buffer].value if pad_len > 0
        [pad_len, token]
      end

      # @return [String] the unencrypted response string
      def winrm_decrypt(str)
        @logger.debug "Decrypting SOAP message:\n#{str}"
        iov_cnt = 3
        iov = FFI::MemoryPointer.new(GSSAPI::LibGSSAPI::GssIOVBufferDesc.size * iov_cnt)

        iov0 = GSSAPI::LibGSSAPI::GssIOVBufferDesc.new(FFI::Pointer.new(iov.address))
        iov0[:type] = (GSSAPI::LibGSSAPI::GSS_IOV_BUFFER_TYPE_HEADER | \
          GSSAPI::LibGSSAPI::GSS_IOV_BUFFER_FLAG_ALLOCATE)

        iov1 = GSSAPI::LibGSSAPI::GssIOVBufferDesc.new(
          FFI::Pointer.new(iov.address + (GSSAPI::LibGSSAPI::GssIOVBufferDesc.size * 1)))
        iov1[:type] = (GSSAPI::LibGSSAPI::GSS_IOV_BUFFER_TYPE_DATA)

        iov2 = GSSAPI::LibGSSAPI::GssIOVBufferDesc.new(
          FFI::Pointer.new(iov.address + (GSSAPI::LibGSSAPI::GssIOVBufferDesc.size * 2)))
        iov2[:type] = (GSSAPI::LibGSSAPI::GSS_IOV_BUFFER_TYPE_DATA)

        str.force_encoding('BINARY')
        str.sub!(/^.*Content-Type: application\/octet-stream\r\n(.*)--Encrypted.*$/m, '\1')

        len = str.unpack('L').first
        iov_data = str.unpack("LA#{len}A*")
        iov0[:buffer].value = iov_data[1]
        iov1[:buffer].value = iov_data[2]

        min_stat = FFI::MemoryPointer.new :uint32
        conf_state = FFI::MemoryPointer.new :uint32
        conf_state.write_int(1)
        qop_state = FFI::MemoryPointer.new :uint32
        qop_state.write_int(0)

        maj_stat = GSSAPI::LibGSSAPI.gss_unwrap_iov(
          min_stat, @gsscli.context, conf_state, qop_state, iov, iov_cnt)

        @logger.debug "SOAP message decrypted (MAJ: #{maj_stat}, " \
          "MIN: #{min_stat.read_int}):\n#{iov1[:buffer].value}"

        iov1[:buffer].value
      end
      # rubocop:enable Metrics/MethodLength
      # rubocop:enable Metrics/AbcSize
    end
    # rubocop:enable Metrics/ClassLength
  end
end # WinRM
