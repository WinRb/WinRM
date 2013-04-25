module WinRM
  module Request
    class WriteStdin < Base
      
      attr_accessor :shell_id
      attr_accessor :command_id
      attr_accessor :text

      def body
        { "#{NS_WIN_SHELL}:Send" => {
            "#{NS_WIN_SHELL}:Stream" => {
             "@Name" => 'stdin',
             "@CommandId" => command_id,
             :content! => Base64.encode64(text)
            }
          }

        }
      end

      def header
        merge_headers(base_headers,RESOURCE_URI_CMD,ACTION_SEND,selector_shell_id(shell_id))
      end

      def execute
        response = client.send_message(self.to_s)
        return true
      end

    end  
  end
end
