# encoding: UTF-8
#
# Copyright 2014 Shawn Neal <sneal@sneal.net>
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

require 'rexml/document'

module WinRM
  # Handles the raw WinRM HTTP response. Returns the body as an XML doc
  # or raises the appropriate WinRM error if the response is an error.
  class ResponseHandler
    # @param [String] The raw unparsed response body, if any
    # @param [Integer] The HTTP response status code
    def initialize(response_body, status_code)
      @response_body = response_body
      @status_code = status_code
    end

    # Processes the response from the WinRM service and either returns an XML
    # doc or raises an appropriate error.
    #
    # @returns [REXML::Document] The parsed response body
    def parse_to_xml
      raise_if_error
      response_xml
    end

    private

    def response_xml
      @response_xml ||= REXML::Document.new(@response_body)
    rescue REXML::ParseException => e
      raise WinRMHTTPTransportError.new(
        "Unable to parse WinRM response: #{e.message}", @status_code)
    end

    def raise_if_error
      return if @status_code == 200
      raise_if_auth_error
      raise_if_wsman_fault
      raise_if_wmi_error
      raise_transport_error
    end

    def raise_if_auth_error
      fail WinRMAuthorizationError if @status_code == 401
    end

    def raise_if_wsman_fault
      soap_errors = REXML::XPath.match(response_xml, "//#{NS_SOAP_ENV}:Body/#{NS_SOAP_ENV}:Fault/*")
      return if soap_errors.empty?
      fault = REXML::XPath.first(soap_errors, "//#{NS_WSMAN_FAULT}:WSManFault")
      fail WinRMWSManFault.new(fault.to_s, fault.attributes['Code']) unless fault.nil?
    end

    def raise_if_wmi_error
      soap_errors = REXML::XPath.match(response_xml, "//#{NS_SOAP_ENV}:Body/#{NS_SOAP_ENV}:Fault/*")
      return if soap_errors.empty?

      error = REXML::XPath.first(soap_errors, "//#{NS_WSMAN_MSFT}:MSFT_WmiError")
      return if error.nil?

      error_code = REXML::XPath.first(error, "//#{NS_WSMAN_MSFT}:error_Code").text
      fail WinRMWMIError.new(error.to_s, error_code)
    end

    def raise_transport_error
      fail WinRMHTTPTransportError.new('Bad HTTP response returned from server', @status_code)
    end
  end
end
