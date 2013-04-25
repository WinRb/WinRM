module WinRM
  module Mixins
    module WmiEnumeration
      def execute
        response = client.send_message(self.to_s)
        xml = Nokogiri::XML(response)

        result = []
        result += parse_items(xml, NS_WSMAN_DMTF)

        while (xml.xpath("//#{NS_ENUM}:EndOfSequence").count + xml.xpath("//#{NS_WSMAN_DMTF}:EndOfSequence").count).eql?(0)
          context = xml.xpath('//n:EnumerationContext').text
          enumeration = WinRM::Request::Enumerate.new( client, context: context, resource_uri: resource_uri )
          xml = enumeration.execute
          result += parse_items(xml,NS_ENUM)
        end 

        result
      
      end

      def parse_items(xml,ns)
        parser = Nori.new(:advanced_typecasting => false, :strip_namespaces => true, :convert_tags_to => lambda { |tag| tag.snakecase.to_sym })
        items = parser.parse(xml.xpath("//#{ns}:Items",xml.collect_namespaces).to_xml)[:items]
        if items.nil?
          return []
        else
          if items.first[1].is_a?(Array)
            return items.first[1]
          else
            return [items.first[1]]
          end
        end
      end
    end
  end
end
