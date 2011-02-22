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
      end

      def send_request(message)
        hdr = {'Content-Type' => 'application/soap+xml;charset=UTF-8', 'Content-Length' => message.length}
        resp = @httpcli.post(@endpoint, message, hdr)
        if(resp.status == 200)
          # Version 1.1 of WinRM adds the namespaces in the document instead of the envelope so we have to
          # add them ourselves here. This should have no affect version 2.
          doc = Nokogiri::XML(resp.body.content)
          doc.collect_namespaces.each_pair do |k,v|
            doc.root.add_namespace((k.split(/:/).last),v) unless doc.namespaces.has_key?(k)
          end
          return doc
        else
          puts "RESPONSE was #{resp.status}"
          # TODO: raise error
        end
      end

      # This will remove Negotiate authentication for plaintext and SSL because it supercedes Basic
      # when it shouldn't for these types of transports.
      def basic_auth_only!
        auths = @httpcli.www_auth.instance_variable_get('@authenticator')
        auths.delete_if {|i| i.scheme !~ /basic/i}
      end
    end

    class HttpPlaintext < HttpTransport
      def initialize(endpoint, user, pass)
        super(endpoint)
        @httpcli.set_auth(nil, user, pass)
        basic_auth_only!
      end
    end

    # Uses SSL to secure the transport
    class HttpSSL < HttpTransport
      def initialize(endpoint, user, pass, ca_trust_path = nil)
        super(endpoint)
        @httpcli.set_auth(endpoint, user, pass)
        @httpcli.ssl_config.set_trust_ca(ca_trust_path) unless ca_trust_path.nil?
        basic_auth_only!
      end
    end

    # Uses Kerberos/GSSAPI to authenticate and encrypt messages
    class HttpGSSAPI < HttpTransport
      # @param [String,URI] endpoint the WinRM webservice endpoint
      # @param [String] realm the Kerberos realm we are authenticating to
      # @param [String<optional>] service the service name, default is HTTP
      # @param [String<optional>] keytab the path to a keytab file if you are using one
      def initialize(endpoint, realm, service = nil, keytab = nil)
        super(endpoint)
        service ||= 'HTTP'
        @service = "#{service}/#{@endpoint.host}@#{realm}"
        init_krb
      end

      def set_auth(user,pass)
        # raise Error
      end

      def send_request(msg)
        original_length = msg.length
        emsg = winrm_encrypt(msg)
        hdr = {
          "Connection" => "Keep-Alive",
          "Content-Type" => "multipart/encrypted;protocol=\"application/HTTP-Kerberos-session-encrypted\";boundary=\"Encrypted Boundary\""
        }

        body = <<-EOF
--Encrypted Boundary\r
Content-Type: application/HTTP-Kerberos-session-encrypted\r
OriginalContent: type=application/soap+xml;charset=UTF-8;Length=#{original_length}\r
--Encrypted Boundary\r
Content-Type: application/octet-stream\r
#{emsg}--Encrypted Boundary\r
        EOF

        r = @httpcli.post(@endpoint, body, hdr)

        winrm_decrypt(r.body.content)
      end


      private 


      def init_krb
        @gsscli = GSSAPI::Simple.new(@endpoint.host, @service)
        token = @gsscli.init_context
        auth = Base64.strict_encode64 token

        hdr = {"Authorization" => "Kerberos #{auth}",
          "Connection" => "Keep-Alive",
          "Content-Type" => "application/soap+xml;charset=UTF-8"
        }
        r = @httpcli.post(@endpoint, '', hdr)
        itok = r.header["WWW-Authenticate"].pop
        itok = itok.split.last
        itok = Base64.strict_decode64(itok)
        @gsscli.init_context(itok)
      end

      # @return [String] the encrypted request string
      def winrm_encrypt(str)
        iov_cnt = 2
        iov = FFI::MemoryPointer.new(GSSAPI::LibGSSAPI::GssIOVBufferDesc.size * iov_cnt)

        iov0 = GSSAPI::LibGSSAPI::GssIOVBufferDesc.new(FFI::Pointer.new(iov.address))
        iov0[:type] = (GSSAPI::LibGSSAPI::GSS_IOV_BUFFER_TYPE_HEADER | GSSAPI::LibGSSAPI::GSS_IOV_BUFFER_FLAG_ALLOCATE)

        iov1 = GSSAPI::LibGSSAPI::GssIOVBufferDesc.new(FFI::Pointer.new(iov.address + (GSSAPI::LibGSSAPI::GssIOVBufferDesc.size * 1)))
        iov1[:type] =  (GSSAPI::LibGSSAPI::GSS_IOV_BUFFER_TYPE_DATA)
        iov1[:buffer].value = str

        conf_state = FFI::MemoryPointer.new :uint32
        min_stat = FFI::MemoryPointer.new :uint32

        maj_stat = GSSAPI::LibGSSAPI.gss_wrap_iov(min_stat, @gsscli.context, 1, 0, conf_state, iov, iov_cnt)

        token = [iov0[:buffer].length].pack('L')
        token += iov0[:buffer].value
        token += iov1[:buffer].value
      end


      # @return [String] the unencrypted response string
      def winrm_decrypt(str)
        iov_cnt = 2
        iov = FFI::MemoryPointer.new(GSSAPI::LibGSSAPI::GssIOVBufferDesc.size * iov_cnt)

        iov0 = GSSAPI::LibGSSAPI::GssIOVBufferDesc.new(FFI::Pointer.new(iov.address))
        iov0[:type] = (GSSAPI::LibGSSAPI::GSS_IOV_BUFFER_TYPE_HEADER | GSSAPI::LibGSSAPI::GSS_IOV_BUFFER_FLAG_ALLOCATE)

        iov1 = GSSAPI::LibGSSAPI::GssIOVBufferDesc.new(FFI::Pointer.new(iov.address + (GSSAPI::LibGSSAPI::GssIOVBufferDesc.size * 1)))
        iov1[:type] =  (GSSAPI::LibGSSAPI::GSS_IOV_BUFFER_TYPE_DATA)

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

        Nokogiri::XML(iov1[:buffer].value)
      end

    end
  end
end # WinRM
