module WinRM
  module Request
    class ReadOutputStreams < Base
      
      attr_accessor :shell_id
      attr_accessor :command_id
      attr_accessor :stdout
      attr_accessor :stderr
      attr_reader :exit_code

      def initialize(*args)
        super
        @stdout = StringIO.new if @stdout.nil?
        @stderr = StringIO.new if @stderr.nil?

        raise ArgumentError, ':stdout must respond to write.' unless @stdout.respond_to?(:write) 
        raise ArgumentError, ':stderr must respond to write.' unless @stderr.respond_to?(:write) 
      end

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

      def execute
        
        begin
          read_streams
        end while exit_code.nil?

        self
      end

      def command_done?(response)
        not response.xpath("//#{NS_WIN_SHELL}:CommandState[@State='http://schemas.microsoft.com/wbem/wsman/1/windows/shell/CommandState/Done']").empty?
      end

      def read_streams
        response = Nokogiri::XML(client.send_message(self.to_s))
        response.xpath("//#{NS_WIN_SHELL}:Stream").each do |s|
          next if s.text.nil? || s.text.empty?
          
          case s['Name'].downcase
          when 'stdout'
            stdout.write Base64.decode64(s.text)
          when 'stderr'
            stderr.write Base64.decode64(s.text)
          else
            raise ArgumentError, "Invalid Stream #{s['Name'].downcase}"
          end
        end

        @exit_code = response.xpath("//rsp:ExitCode").text.to_i if command_done?(response)
        
        nil
      end 

    end
  end
end
