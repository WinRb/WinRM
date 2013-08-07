module WinRM
  module Request
    class OpenShell < Base

      attr_accessor :codepage
      attr_accessor :noprofile
      attr_accessor :input_stream
      attr_accessor :output_streams
      attr_accessor :working_directory
      attr_accessor :idle_timeout
      attr_accessor :env_vars

      def initialize(*args)
        super
        @codepage = 437 if @codepage.nil?
        @noprofile = false if @noprofile.nil?
        @input_stream = 'stdin' if @input_stream.nil?
        @output_streams = 'stdout stderr' if @output_streams.nil?
      end

      def body
        message = { "#{NS_WIN_SHELL}:Shell" => {
                    "#{NS_WIN_SHELL}:InputStreams" => input_stream,
                    "#{NS_WIN_SHELL}:OutputStreams" => output_streams
                    }
                  }

        message["#{NS_WIN_SHELL}:Shell"]["#{NS_WIN_SHELL}:WorkingDirectory"] = working_directory unless working_directory.nil?
        # TODO: research Lifetime a bit more: http://msdn.microsoft.com/en-us/library/cc251546(v=PROT.13).aspx
        #s.body["#{NS_WIN_SHELL}:Lifetime"] = sec_to_dur(shell_opts[:lifetime]) if(shell_opts.has_key?(:lifetime) && shell_opts[:lifetime].is_a?(Fixnum))
        # @todo make it so the input is given in milliseconds and converted to xs:duration
        message["#{NS_WIN_SHELL}:Shell"]["#{NS_WIN_SHELL}:IdleTimeOut"] = idle_timeout unless idle_timeout.nil?

        unless env_vars.nil? or ( env_vars.is_a?(Hash) && env_vars.empty? )
          keys = env_vars.keys
          vals = env_vars.values
          message["#{NS_WIN_SHELL}:Shell"]["#{NS_WIN_SHELL}:Environment"] = {
            "#{NS_WIN_SHELL}:Variable" => vals,
            :attributes! => {"#{NS_WIN_SHELL}:Variable" => {'Name' => keys}}
          }
        end
        message
      end

      def header
          merge_headers(base_headers,RESOURCE_URI_CMD,ACTION_CREATE,shell_options)
      end

      def execute
        response = Nokogiri::XML(client.send_message(self.to_s))
        response.xpath("//#{NS_WSMAN_DMTF}:Selector[@Name='ShellId']/text()").to_s
      end

      private
      def shell_options
        { "#{NS_WSMAN_DMTF}:OptionSet" => { "#{NS_WSMAN_DMTF}:Option" => [noprofile.to_s.upcase, codepage],
                        :attributes! => {"#{NS_WSMAN_DMTF}:Option" => {'Name' => ['WINRS_NOPROFILE','WINRS_CODEPAGE']}}}
        }
      end
    end  
  end
end
