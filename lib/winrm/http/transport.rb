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
        ssl_peer_fingerprint_verification!
        log_soap_message(message)
        hdr = { 'Content-Type' => 'application/soap+xml;charset=UTF-8',
                'Content-Length' => message.bytesize }
        resp = @httpcli.post(@endpoint, message, hdr)
        log_soap_message(resp.http_body.content)
        verify_ssl_fingerprint(resp.peer_cert)
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

      # SSL Peer Fingerprint Verification prior to connecting
      def ssl_peer_fingerprint_verification!
        return unless @ssl_peer_fingerprint && ! @ssl_peer_fingerprint_verified

        with_untrusted_ssl_connection do |connection|
          connection_cert = connection.peer_cert_chain.last
          verify_ssl_fingerprint(connection_cert)
        end
        @logger.info("initial ssl fingerprint #{@ssl_peer_fingerprint} verified\n")
        @ssl_peer_fingerprint_verified = true
        no_ssl_peer_verification!
      end

      # Connect without verification to retrieve untrusted ssl context
      def with_untrusted_ssl_connection
        noverify_peer_context = OpenSSL::SSL::SSLContext.new
        noverify_peer_context.verify_mode = OpenSSL::SSL::VERIFY_NONE
        tcp_connection = TCPSocket.new(@endpoint.host, @endpoint.port)
        begin
          ssl_connection = OpenSSL::SSL::SSLSocket.new(tcp_connection, noverify_peer_context)
          ssl_connection.connect
          yield ssl_connection
        ensure
          tcp_connection.close
        end
      end

      # compare @ssl_peer_fingerprint to current ssl context
      def verify_ssl_fingerprint(cert)
        return unless @ssl_peer_fingerprint
        conn_fingerprint = OpenSSL::Digest::SHA1.new(cert.to_der).to_s
        return unless @ssl_peer_fingerprint.casecmp(conn_fingerprint) != 0
        fail "ssl fingerprint mismatch!!!!\n"
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
        puts endpoint
        super(endpoint)
        puts endpoint
        @httpcli.set_auth(nil, user, pass)
        no_sspi_auth! if opts[:disable_sspi]
        basic_auth_only! if opts[:basic_auth_only]
        no_ssl_peer_verification! if opts[:no_ssl_peer_verification]
      end
    end


    # NTLM/Negotiate, secure, HTTP transport
    class HttpNegotiate < HttpTransport
      def initialize(endpoint, user, pass, opts)
        super(endpoint)
        require 'rubyntlm'
        no_sspi_auth!

        user_parts = user.split('\\')
        if(user_parts.length > 1)
          opts[:domain] = user_parts[0]
          user = user_parts[1]
        end

        @ntlmcli = Net::NTLM::Client.new(user, pass, opts)
        @retryable = true
        no_ssl_peer_verification! if opts[:no_ssl_peer_verification]
        @ssl_peer_fingerprint = opts[:ssl_peer_fingerprint]
        @httpcli.ssl_config.set_trust_ca(opts[:ca_trust_path]) if opts[:ca_trust_path]
      end

      def send_request(message, auth_header = nil)
        ssl_peer_fingerprint_verification!
        auth_header = init_auth if @ntlmcli.session.nil?

        original_length = message.bytesize

        emessage = @ntlmcli.session.seal_message message
        signature = @ntlmcli.session.sign_message message
        seal = "\x10\x00\x00\x00#{signature}#{emessage}"

        hdr = {
          "Content-Type" => "multipart/encrypted;protocol=\"application/HTTP-SPNEGO-session-encrypted\";boundary=\"Encrypted Boundary\""
        }
        hdr.merge!(auth_header) if auth_header

        body = [
          "--Encrypted Boundary",
          "Content-Type: application/HTTP-SPNEGO-session-encrypted",
          "OriginalContent: type=application/soap+xml;charset=UTF-8;Length=#{original_length}",
          "--Encrypted Boundary",
          "Content-Type: application/octet-stream",
          "#{seal}--Encrypted Boundary--",
          ""
        ].join("\r\n")

        resp = @httpcli.post(@endpoint, body, hdr)
        verify_ssl_fingerprint(resp.peer_cert)
        if resp.status == 401 && @retryable
          @retryable = false
          send_request(message, init_auth)
        else
          @retryable = true
          decrypted_body = resp.body.empty? ? '' : winrm_decrypt(resp.body)
          handler = WinRM::ResponseHandler.new(decrypted_body, resp.status)
          handler.parse_to_xml()
        end
      end

      private

      def winrm_decrypt(str)
        str.force_encoding('BINARY')
        str.sub!(/^.*Content-Type: application\/octet-stream\r\n(.*)--Encrypted.*$/m, '\1')

        signature = str[4..19]
        message = @ntlmcli.session.unseal_message str[20..-1]
        if @ntlmcli.session.verify_signature(signature, message)
          message
        else
          raise WinRMWebServiceError, "Could not verify SOAP message."
        end
      end

      def init_auth
        @logger.debug "Initializing Negotiate for #{@service}"
        auth1 = @ntlmcli.init_context
        hdr = {"Authorization" => "Negotiate #{auth1.encode64}",
               "Content-Type" => "application/soap+xml;charset=UTF-8"
        }
        @logger.debug "Sending HTTP POST for Negotiate Authentication"
        r = @httpcli.post(@endpoint, "", hdr)
        verify_ssl_fingerprint(r.peer_cert)
        itok = r.header["WWW-Authenticate"].pop.split.last
        binding = r.peer_cert.nil? ? nil : Net::NTLM::ChannelBinding.create(r.peer_cert)
        auth3 = @ntlmcli.init_context(itok, binding)
        { "Authorization" => "Negotiate #{auth3.encode64}" }
      end
    end

    # Uses SSL to secure the transport
    class BasicAuthSSL < HttpTransport
      def initialize(endpoint, user, pass, opts)
        super(endpoint)
        @httpcli.set_auth(endpoint, user, pass)
        basic_auth_only!
        no_ssl_peer_verification! if opts[:no_ssl_peer_verification]
        @ssl_peer_fingerprint = opts[:ssl_peer_fingerprint]
        @httpcli.ssl_config.set_trust_ca(opts[:ca_trust_path]) if opts[:ca_trust_path]
      end
    end

    # Uses Kerberos/GSSAPI to authenticate and encrypt messages
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

      # Sends the SOAP payload to the WinRM service and returns the service's
      # HTTP response.
      #
      # @param [String] The XML SOAP message
      # @returns [Object] The HTTP response object
      def send_kerberos_request(message)
        log_soap_message(message)
        original_length = message.bytesize
        pad_len, emsg = winrm_encrypt(message)
        hdr = {
          'Connection' => 'Keep-Alive',
          'Content-Type' =>
            'multipart/encrypted;' \
            'protocol="application/HTTP-Kerberos-session-encrypted";' \
            'boundary="Encrypted Boundary"'
        }
        body = [
          "--Encrypted Boundary",
          "Content-Type: application/HTTP-Kerberos-session-encrypted",
          "OriginalContent: type=application/soap+xml;charset=UTF-8;Length=#{original_length + pad_len}",
          "--Encrypted Boundary",
          "Content-Type: application/octet-stream",
          "#{emsg}--Encrypted Boundary--",
          ""
        ].join("\r\n")

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
    end
  end
end # WinRM
