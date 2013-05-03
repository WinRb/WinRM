module WinRM
  module Request
    class ReadOutputStreams < Base
      
      attr_accessor :shell_id
      attr_accessor :command_id
      attr_accessor :stdout
      attr_accessor :stderr
      attr_reader :exit_code

      def body
        { "#{NS_WIN_SHELL}:Receive" => {
            "#{NS_WIN_SHELL}:DesiredStream" => 'stdout stderr',
              :attributes! => {"#{NS_WIN_SHELL}:DesiredStream" => {'CommandId' => command_id}}
            }
        }
      end

      def header
        merge_headers(base_headers,RESOURCE_URI_CMD,ACTION_RECEIVE,selector_shell_id(shell_id))
      end

      def execute(&block)

        begin
          read_streams(&block)
        end while exit_code.nil?

        return exit_code
      end

      def command_done?(response)
        not response.xpath("//#{NS_WIN_SHELL}:CommandState[@State='http://schemas.microsoft.com/wbem/wsman/1/windows/shell/CommandState/Done']").empty?
      end

      def read_streams(&block)
        response = Nokogiri::XML(client.send_message(self.to_s))
        response.xpath("//#{NS_WIN_SHELL}:Stream").each do |s|
          next if s.text.nil? || s.text.empty?
          yield( s['Name'].downcase.to_sym, Base64.decode64(s.text) )
        end

        @exit_code = response.xpath("//rsp:ExitCode").text.to_i if command_done?(response)
        
      end 

    end
  end
end
