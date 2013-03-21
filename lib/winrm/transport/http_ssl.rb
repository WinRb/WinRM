module WinRM
  module Transport
    class HttpSSL < Base
      def initialize(endpoint, opts)
        super(endpoint, opts)
        @httpcli.set_auth(endpoint, opts[:user], opts[:pass])
        @httpcli.ssl_config.set_trust_ca(opts[:ca_trust_path]) unless opts[:ca_trust_path].nil?
        no_sspi_auth! #if opts[:disable_sspi]
        basic_auth_only! if opts[:basic_auth_only]
      end

      alias_method :send_request_base, :send_request

      def send_request(message) 
        begin
          send_request_base(message)
        rescue OpenSSL::SSL::SSLError => e
          if opts[:trust_all_certs]
            warn 'The remote host\'s certificate cannot be verified'
            @httpcli.ssl_config.verify_callback = proc { true }
            @httpcli.ssl_config.verify_mode = OpenSSL::SSL::VERIFY_NONE
            send_request_base(message)
          else
            error ["Certificate cannot be verified, you can specify a trusted ca using :ca_trust_path:",
                    "'/path/to/ca' or you can trust all ca (including self signed) using trust_all_certs: true"].join(' ')
            raise e
          end
        end
      end


    end
  end
end