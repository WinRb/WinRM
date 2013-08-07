module WinRM
  module Request
    class CloseCommand < Base
      
      attr_accessor :shell_id
      attr_accessor :command_id

      def body
        { "#{NS_WIN_SHELL}:Signal" => {
           "@CommandId" => command_id,
           :content! => {
            "#{NS_WIN_SHELL}:Code" => "http://schemas.microsoft.com/wbem/wsman/1/windows/shell/signal/terminate"
           }
          }

        }
      end

      def header
        merge_headers(base_headers,RESOURCE_URI_CMD,get_action(:signal),selector_shell_id(shell_id))
      end

      def execute
        client.send_message(self.to_s)
        return true
      end

    end  
  end
end
