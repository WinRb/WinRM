module WinRM
  module Transport
    class HttpPlaintext < Base
      def initialize(endpoint, opts)
        super(endpoint, opts)
#        @httpcli.set_auth(nil, opts[:user], opts[:pass])
#        @httpcli.debug_dev = STDOUT
#        #no_sspi_auth! #if opts[:disable_sspi]
#        basic_auth_only!# if opts[:basic_auth_only]
      end
    end
  end
end