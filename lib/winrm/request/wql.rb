module WinRM
  module Request
    class Wql < Base

      include Mixins::WmiEnumeration
      
      attr_accessor :wmi_namespace
      attr_accessor :query
      attr_accessor :max_elements

      def initialize(*args)
        super
        @wmi_namespace = 'root/cimv2/*' if wmi_namespace.nil? 
        @max_elements = 32000 if max_elements.nil?
      end

      def body
        { "#{NS_ENUM}:Enumerate" => {
            "#{NS_WSMAN_DMTF}:OptimizeEnumeration" => nil,
            "#{NS_WSMAN_DMTF}:MaxElements" => max_elements,
            "#{NS_WSMAN_DMTF}:Filter" => { 
                '@Dialect' => 'http://schemas.microsoft.com/wbem/wsman/1/WQL',
                :content! => query || (raise ArgumentError, 'Query cannot be null'),
              }
          }
        }
      end

      def header
        merge_headers(base_headers,resource_uri,get_action(:enumerate))
      end

      def resource_uri
        {"#{NS_WSMAN_DMTF}:ResourceURI" => "http://schemas.microsoft.com/wbem/wsman/1/wmi/#{wmi_namespace}",
          :attributes! => {"#{NS_WSMAN_DMTF}:ResourceURI" => {'mustUnderstand' => true}}}
      end

    end  
  end
end


