=begin
  This file is part of WinRM; the Ruby library for Microsoft WinRM.

  Copyright © 2010 Dan Wanek <dan.wanek@gmail.com>

  Licensed under the Apache License, Version 2.0 (the "License");
  you may not use this file except in compliance with the License.
  You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

  Unless required by applicable law or agreed to in writing, software
  distributed under the License is distributed on an "AS IS" BASIS,
  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
  See the License for the specific language governing permissions and
  limitations under the License.
=end

module WinRM
  # Generic WinRM SOAP Error
  class WinRMWebServiceError < StandardError
  end

  # Authorization Error
  class WinRMAuthorizationError < StandardError
  end

  # A Fault returned in the SOAP response. The XML node is a WSManFault
  class WinRMWSManFault < StandardError; end

  # Bad HTTP Transport
  class WinRMHTTPTransportError < StandardError
    
    attr_reader :response

    def initialize(msg,response)
      super(msg)
      @response = response
    end

    def http_body
      response.http_body.content
    end

    def xml
      @xml ||= Nokogiri::XML(http_body)
    end

    def reason
      xml.xpath('//s:Reason/s:Text[@xml:lang="en-US"]').text.strip.chomp
    end

    def detail      
      @detail ||= begin
        parser = Nori.new(:strip_namespaces => true, :convert_tags_to => lambda { |tag| tag.snakecase.to_sym })
        parser.parse(xml.xpath("//s:Detail").to_xml)[:detail]
      end
    end

    def provider
      xml.xpath("//f:WSManFault/f:Message/f:ProviderFault/@provider",xml.collect_namespaces)[0].value
    end

    def code
      xml.xpath("//f:WSManFault/f:Message/f:ProviderFault/f:WSManFault/@Code", xml.collect_namespaces)[0].value.to_i
    end

    def fault_message
      xml.xpath("//f:WSManFault/f:Message/f:ProviderFault/f:WSManFault/f:Message", xml.collect_namespaces)[0].text.strip.chomp
    end

  end

  class WinRMGenericError < StandardError; end
end # WinRM

