module WinRM
  module Request
    class CloseShell < Base
      
      attr_accessor :shell_id

      def body
        nil
      end

      def header
        merge_headers(base_headers,RESOURCE_URI_CMD,get_action(:delete),selector_shell_id(shell_id))
      end

      def execute
        client.send_message(self.to_s)
        return true
      end

    end  
  end
end
