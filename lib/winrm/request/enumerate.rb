module WinRM
  module Request
    class Enumerate < Base
      
      attr_accessor :context
      attr_accessor :max_elements
      attr_accessor :timeout
      attr_accessor :resource_uri
      attr_accessor :session_id

      def initialize(*args)
        super
        @max_elements ||= 32000
        @timeout ||= 'PT60S'
      end

      def body
        { "#{NS_ENUM}:Pull" => {
           "#{NS_ENUM}:EnumerationContext" => context,
           "#{NS_ENUM}:MaxElements" => max_elements
          }

        }
      end

      def header
        merge_headers(base_headers,get_action(:enumerate_pull),resource_uri)
      end

      def execute
        Nokogiri::XML(client.send_message(self.to_s))
      end

    end  
  end
end