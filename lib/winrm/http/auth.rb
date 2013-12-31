
require 'httpclient/auth'

class HTTPClient

  class WWWAuth

    # Filter API implementation.  Traps HTTP request and insert
    # 'Authorization' header if needed.
    def filter_request(req)
      @authenticator.each do |auth|
        next unless auth.set? # hasn't be set, don't use it
        if cred = auth.get(req)
          auth.encrypt_payload(req) if auth.respond_to?(:encrypt_payload)
          req.header.set('Authorization', auth.scheme + " " + cred)
          return
        end
      end
    end

    # Filter API implementation.  Traps HTTP response and parses
    # 'WWW-Authenticate' header.
    #
    # This remembers the challenges for all authentication methods
    # available to the client. On the subsequent retry of the request,
    # filter_request will select the strongest method.
    def filter_response(req, res)
      command = nil
      if res.status == HTTP::Status::UNAUTHORIZED
        if challenge = parse_authentication_header(res, 'www-authenticate')
          uri = req.header.request_uri
          challenge.each do |scheme, param_str|
            @authenticator.each do |auth|
              next unless auth.set? # hasn't be set, don't use it
              if scheme.downcase == auth.scheme.downcase
                challengeable = auth.challenge(uri, param_str)
                command = :retry if challengeable
              end
            end
          end
          # ignore unknown authentication scheme
        end
      elsif res.status == HTTP::Status::OK
        decrypted_content = res.content
        @authenticator.each do |auth|
          next unless auth.set? # hasn't be set, don't use it
          decrypted_content = auth.decrypt_payload(res.content) if auth.respond_to?(:encrypted_channel?) and auth.encrypted_channel?
        end
        # update with decrypted content
        res.content.replace(decrypted_content) if res.content and !res.content.empty?
      end
      command
    end
  end

  class SSPINegotiateAuth
    # Response handler: returns credential.
    # See win32/sspi for negotiation state transition.
    def get(req)
      return nil unless SSPIEnabled || GSSAPIEnabled
      target_uri = req.header.request_uri
      domain_uri, param = @challenge.find { |uri, v|
        Util.uri_part_of(target_uri, uri)
      }

      return nil unless param
      state = param[:state]
      authenticator = param[:authenticator]
      authphrase = param[:authphrase]
      case state
      when :init
        if SSPIEnabled
          # Over-ride ruby win32 sspi to support encrypt/decrypt
          require 'winrm/win32/sspi'
          authenticator = param[:authenticator] = Win32::SSPI::NegotiateAuth.new
          @authenticator = authenticator #  **** Hacky remember as we need this for encrypt/decrypt
          return authenticator.get_initial_token
        else # use GSSAPI
          authenticator = param[:authenticator] = GSSAPI::Simple.new(domain_uri.host, 'HTTP')
          # Base64 encode the context token
          return [authenticator.init_context].pack('m').gsub(/\n/,'')
        end
      when :response
        @challenge.delete(domain_uri)
        if SSPIEnabled
          return authenticator.complete_authentication(authphrase)
        else # use GSSAPI
          return authenticator.init_context(authphrase.unpack('m').pop)
        end
      end
      nil
    end

    def encrypted_channel?
      @encrypted_channel
    end

    def encrypt_payload(req)
      if SSPIEnabled
        body = @authenticator.encrypt_payload(req.body)
        req.http_body = HTTP::Message::Body.new
        req.http_body.init_request(body)
        req.http_header.body_size = body.length if body
        # if body is encrypted update the header
        if body.include? "HTTP-SPNEGO-session-encrypted"
          @encrypted_channel = true
          req.header.set('Content-Type', "multipart/encrypted;protocol=\"application/HTTP-SPNEGO-session-encrypted\";boundary=\"Encrypted Boundary\"")
        end
      end
    end

    def decrypt_payload(body)
      body = @authenticator.decrypt_payload(body) if SSPIEnabled
      body
    end
  end
end