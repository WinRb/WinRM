module WinRM
  module Request
    class Base
      
      include WinRM::Headers

      attr_accessor :opts
      attr_reader :client
      attr_accessor :selectors
      
      def initialize(client, opts = {})
        @client = client
        @opts = opts
        
        @opts[:endpoint] = client.endpoint

        @opts.each do |key,value|
          if respond_to?("#{key}=")
            WinRM.logger.debug "#{self.class}: Setting #{key} => #{value}"
            send("#{key}=",value)
          end
        end

        @selectors ||= {}
      end

      def to_s
        root_node = namespaces_to_attrs

        root_node[:content!] = {
          "#{NS_SOAP_ENV}:Header" => header,
          "#{NS_SOAP_ENV}:Body" => body
        }
        '<?xml version="1.0" encoding="UTF-8"?>' << Gyoku.xml({ "#{NS_SOAP_ENV}:Envelope" => root_node })
      end

      def namespaces_to_attrs
        n = NAMESPACES.inject({}) do |r,i|
                          r["@#{i[0]}"] = i[1]
                          r
                        end
        if respond_to?(:local_namespaces) and not local_namespaces.nil?
          n = local_namespaces.inject(n) do |r,i|
                          r["@#{i[0]}"] = i[1]
                          r
                        end
        end
        return n
      end

      def selector_set
        return {} if selectors.empty?
        s = []

        selectors.each do |k,v|
          s << { "#{NS_WSMAN_DMTF}:Selector" => {
                    :content! => v,
                    :@Name => k
                    }
                  }
        end
        return { "#{NS_WSMAN_DMTF}:SelectorSet" => s }
      end

      def body
        raise StandardError, "Not Implemented"
      end

      def header
        raise StandardError, "Not Implemented"
      end
    end

  end
end

