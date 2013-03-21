module WinRM
  module Transport

      # A generic HTTP transport that utilized HTTPClient to send messages back and forth.
    # This backend will maintain state for every WinRMWebService instance that is instatiated so it
    # is possible to use GSSAPI with Keep-Alive.
    class Base
      include WinRM::Logger
      attr_reader :endpoint
      attr_reader :opts
      
      def initialize(endpoint, opts)
        @endpoint = endpoint.is_a?(String) ? URI.parse(endpoint) : endpoint
        @opts = opts
      end
      
      def base_request
        request = HTTPI::Request.new
        request.url = @endpoint.to_s
        request.read_timeout = 3600
        request.headers['Content-Type'] = 'application/soap+xml;charset=UTF-8'
        request.auth.ntlm opts[:user], opts[:pass], opts[:domain]
      end

      def send_request(message)
        puts message
        request = base_request
        request.headers['Content-Length'] = message.length
        requeset.body = message
        resp = HTTPI.post(request, :net_http)

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
        auths.delete_if {|i| i.scheme =~ /basic/i}
        auths.delete_if {|i| i.is_a? HTTPClient::SSPINegotiateAuth }
      end

      # Disable SSPI Auth
      def no_sspi_auth!
        auths = @httpcli.www_auth.instance_variable_get('@authenticator')
        auths.delete_if {|i| not i.is_a? HTTPClient::SSPINegotiateAuth }
      end
    end
  end
end