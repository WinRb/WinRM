module WinRM
  module Request
    class InvokeWmi < Base
      
      attr_accessor :wmi_class
      attr_accessor :wmi_namespace
      attr_accessor :method
      attr_accessor :arguments
      attr_accessor :selectors

      alias :namespaces_to_attrs :namespaces_to_attrs

      def initialize(*args)
        super
        @wmi_namespace = 'root/cimv2' if wmi_namespace.nil? 
        @arguments ||= {}
        @selectors ||= {}
      end

      def local_namespaces
        { "xmlns:p" => "http://schemas.microsoft.com/wbem/wsman/1/wmi/#{wmi_namespace}/#{wmi_class}" }
      end

      def body
        { "#{NS_WSMAN_MSFT}:#{method}_INPUT" => arguments.inject({}) do |r,i|
                                                  r["#{NS_WSMAN_MSFT}:#{i[0]}"] = i[1]
                                                  r
                                                end
        }
      end

      def header
        merge_headers(base_headers,resource_uri,invoke_action_header,selector_set)
      end

      def invoke_action_header
        { "#{NS_ADDRESSING}:Action" => "http://schemas.microsoft.com/wbem/wsman/1/wmi/#{wmi_namespace}/#{wmi_class}/#{method}",
            :attributes! => {"#{NS_ADDRESSING}:Action" => {'mustUnderstand' => true}}
        }
      end

      def resource_uri
        { "#{NS_WSMAN_DMTF}:ResourceURI" => "http://schemas.microsoft.com/wbem/wsman/1/wmi/#{wmi_namespace}/#{wmi_class}",
          :attributes! => {"#{NS_WSMAN_DMTF}:ResourceURI" => {'mustUnderstand' => true}}
        }
      end

      def execute
          response = Nokogiri::XML(client.send_message(self.to_s))
          parameters = {}
          response.xpath("//p:Create_OUTPUT",response.collect_namespaces).children.each do |c|  parameters[c.name.snakecase] = c.text end 
          parameters
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

    end  
  end
end
