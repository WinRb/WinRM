=begin
  This file is part of WinRM; the Ruby library for Microsoft WinRM.

  Copyright © 2010 Dan Wanek <dan.wanek@gmail.com>

  Licensed under the Apache License, Version 2.0 (the "License");
  you may not use this file except in compliance with the License.
  You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

  Unless required by applicable law or agreed to in writing, software
  distributed under the License is distributed on an "AS IS" BASIS,
  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
  See the License for the specific language governing permissions and
  limitations under the License.
=end

module WinRM
  module HTTP

    # A generic HTTP transport that utilized HTTPClient to send messages back and forth.
    # This backend will maintain state for every WinRMWebService instance that is instatiated so it
    # is possible to use GSSAPI with Keep-Alive.
    class HttpTransport

      attr_reader :endpoint

      def initialize(endpoint)
        @endpoint = endpoint.is_a?(String) ? URI.parse(endpoint) : endpoint
        @httpcli = HTTPClient.new(:agent_name => 'Ruby WinRM Client')
        @httpcli.receive_timeout = 3600 # Set this to an unreasonable amount for now because WinRM has timeouts
        @logger = Logging.logger[self]
      end

      def send_request(message)
        hdr = {'Content-Type' => 'application/soap+xml;charset=UTF-8', 'Content-Length' => message.length}
        resp = @httpcli.post(@endpoint, message, hdr)
        if(resp.status == 200)
          # Version 1.1 of WinRM adds the namespaces in the document instead of the envelope so we have to
          # add them ourselves here. This should have no affect version 2.
          doc = Nokogiri::XML(resp.http_body.content)
          doc.collect_namespaces.each_pair do |k,v|
            doc.root.add_namespace((k.split(/:/).last),v) unless doc.namespaces.has_key?(k)
          end
          return doc
        else
          raise WinRMHTTPTransportError, "Bad HTTP response returned from server (#{resp.status})."
        end
      end

      # We'll need this to force basic authentication if desired
      def basic_auth_only!
        auths = @httpcli.www_auth.instance_variable_get('@authenticator')
        auths.delete_if {|i| i.scheme !~ /basic/i}
      end

      # Disable SSPI Auth
      def no_sspi_auth!
        auths = @httpcli.www_auth.instance_variable_get('@authenticator')
        auths.delete_if {|i| i.is_a? HTTPClient::SSPINegotiateAuth }
      end
    end

    class HttpPlaintext < HttpTransport
      def initialize(endpoint, user, pass, opts)
        super(endpoint)
        @httpcli.set_auth(nil, user, pass)
        no_sspi_auth! if opts[:disable_sspi]
        basic_auth_only! if opts[:basic_auth_only]
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
      end
    end

    # Uses Kerberos/GSSAPI to authenticate and encrypt messages
    class HttpGSSAPI < HttpTransport
      # @param [String,URI] endpoint the WinRM webservice endpoint
      # @param [String] realm the Kerberos realm we are authenticating to
      # @param [String<optional>] service the service name, default is HTTP
      # @param [String<optional>] keytab the path to a keytab file if you are using one
      def initialize(endpoint, realm, service = nil, keytab = nil, opts)
        super(endpoint)
        # Remove the GSSAPI auth from HTTPClient because we are doing our own thing
        auths = @httpcli.www_auth.instance_variable_get('@authenticator')
        auths.delete_if {|i| i.is_a?(HTTPClient::SSPINegotiateAuth)}
        service ||= 'HTTP'
        @service = "#{service}/#{@endpoint.host}@#{realm}"
        init_krb
      end

      def set_auth(user,pass)
        # raise Error
      end

      def send_request(msg)
        original_length = msg.length
        pad_len, emsg = winrm_encrypt(msg)
        hdr = {
          "Connection" => "Keep-Alive",
          "Content-Type" => "multipart/encrypted;protocol=\"application/HTTP-Kerberos-session-encrypted\";boundary=\"Encrypted Boundary\""
        }

        body = <<-EOF
--Encrypted Boundary\r
Content-Type: application/HTTP-Kerberos-session-encrypted\r
OriginalContent: type=application/soap+xml;charset=UTF-8;Length=#{original_length + pad_len}\r
--Encrypted Boundary\r
Content-Type: application/octet-stream\r
#{emsg}--Encrypted Boundary\r
        EOF

        r = @httpcli.post(@endpoint, body, hdr)

        winrm_decrypt(r.http_body.content)
      end


      private 


      def init_krb
        @logger.debug "Initializing Kerberos for #{@service}"
        @gsscli = GSSAPI::Simple.new(@endpoint.host, @service)
        token = @gsscli.init_context
        auth = Base64.strict_encode64 token

        hdr = {"Authorization" => "Kerberos #{auth}",
          "Connection" => "Keep-Alive",
          "Content-Type" => "application/soap+xml;charset=UTF-8"
        }
        @logger.debug "Sending HTTP POST for Kerberos Authentication"
        r = @httpcli.post(@endpoint, '', hdr)
        itok = r.header["WWW-Authenticate"].pop
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
        iov0[:type] = (GSSAPI::LibGSSAPI::GSS_IOV_BUFFER_TYPE_HEADER | GSSAPI::LibGSSAPI::GSS_IOV_BUFFER_FLAG_ALLOCATE)

        iov1 = GSSAPI::LibGSSAPI::GssIOVBufferDesc.new(FFI::Pointer.new(iov.address + (GSSAPI::LibGSSAPI::GssIOVBufferDesc.size * 1)))
        iov1[:type] =  (GSSAPI::LibGSSAPI::GSS_IOV_BUFFER_TYPE_DATA)
        iov1[:buffer].value = str

        iov2 = GSSAPI::LibGSSAPI::GssIOVBufferDesc.new(FFI::Pointer.new(iov.address + (GSSAPI::LibGSSAPI::GssIOVBufferDesc.size * 2)))
        iov2[:type] = (GSSAPI::LibGSSAPI::GSS_IOV_BUFFER_TYPE_PADDING | GSSAPI::LibGSSAPI::GSS_IOV_BUFFER_FLAG_ALLOCATE)

        conf_state = FFI::MemoryPointer.new :uint32
        min_stat = FFI::MemoryPointer.new :uint32

        maj_stat = GSSAPI::LibGSSAPI.gss_wrap_iov(min_stat, @gsscli.context, 1, GSSAPI::LibGSSAPI::GSS_C_QOP_DEFAULT, conf_state, iov, iov_cnt)

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
        iov0[:type] = (GSSAPI::LibGSSAPI::GSS_IOV_BUFFER_TYPE_HEADER | GSSAPI::LibGSSAPI::GSS_IOV_BUFFER_FLAG_ALLOCATE)

        iov1 = GSSAPI::LibGSSAPI::GssIOVBufferDesc.new(FFI::Pointer.new(iov.address + (GSSAPI::LibGSSAPI::GssIOVBufferDesc.size * 1)))
        iov1[:type] =  (GSSAPI::LibGSSAPI::GSS_IOV_BUFFER_TYPE_DATA)

        iov2 = GSSAPI::LibGSSAPI::GssIOVBufferDesc.new(FFI::Pointer.new(iov.address + (GSSAPI::LibGSSAPI::GssIOVBufferDesc.size * 2)))
        iov2[:type] =  (GSSAPI::LibGSSAPI::GSS_IOV_BUFFER_TYPE_DATA)

        str.force_encoding('BINARY')
        str.sub!(/^.*Content-Type: application\/octet-stream\r\n(.*)--Encrypted.*$/m, '\1')

        len = str.unpack("L").first
        iov_data = str.unpack("LA#{len}A*")
        iov0[:buffer].value = iov_data[1]
        iov1[:buffer].value = iov_data[2]

        min_stat = FFI::MemoryPointer.new :uint32
        conf_state = FFI::MemoryPointer.new :uint32
        conf_state.write_int(1)
        qop_state = FFI::MemoryPointer.new :uint32
        qop_state.write_int(0)

        maj_stat = GSSAPI::LibGSSAPI.gss_unwrap_iov(min_stat, @gsscli.context, conf_state, qop_state, iov, iov_cnt)

        @logger.debug "SOAP message decrypted (MAJ: #{maj_stat}, MIN: #{min_stat.read_int}):\n#{iov1[:buffer].value}"

        Nokogiri::XML(iov1[:buffer].value)
      end

    end
  end
end # WinRM
