module WinRM
  module Request
    class StartProcess < Base
      
      attr_accessor :shell_id
      attr_accessor :skip_command_shell
      attr_accessor :batch_mode
      attr_accessor :arguments
      attr_accessor :command

      def initialize(*args)
        super
        @skip_command_shell = false if @skip_command_shell.nil?
        @batch_mode = true if @batch_mode.nil?
      end

      def body
        { "#{NS_WIN_SHELL}:CommandLine" => { 
            "#{NS_WIN_SHELL}:Command" => "\"#{command}\"", 
            "#{NS_WIN_SHELL}:Arguments" => ( arguments || [] ) }
        }
      end

      def header
        merge_headers(base_headers,RESOURCE_URI_CMD,ACTION_COMMAND,command_options,selector_shell_id(shell_id))
      end

      def execute
        response = Nokogiri::XML(client.send_message(self.to_s))
        response.xpath("//#{NS_WIN_SHELL}:CommandId").text.to_s
      end

      private
      def command_options
        { "#{NS_WSMAN_DMTF}:OptionSet" => {
          "#{NS_WSMAN_DMTF}:Option" => [batch_mode.to_s.upcase, skip_command_shell.to_s.upcase],
            :attributes! => {"#{NS_WSMAN_DMTF}:Option" => {'Name' => ['WINRS_CONSOLEMODE_STDIN','WINRS_SKIP_CMD_SHELL']}}}
        }
      end

    end  
  end
end
