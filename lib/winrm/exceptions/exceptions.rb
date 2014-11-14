# Copyright 2010 Dan Wanek <dan.wanek@gmail.com>
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

module WinRM

  # WinRM base class for errors
  class WinRMError < StandardError; end

  # Authorization Error
  class WinRMAuthorizationError < WinRMError; end

  # Error that occurs when a file upload fails
  class WinRMUploadError < WinRMError; end

  # Error that occurs when a file download fails
  class WinRMDownloadError < WinRMError; end

  # A Fault returned in the SOAP response. The XML node is a WSManFault
  class WinRMWSManFault < WinRMError
    attr_reader :fault_code
    attr_reader :fault_description

    def initialize(fault_description, fault_code)
      @fault_description = fault_description
      @fault_code = fault_code
      super("[WSMAN ERROR CODE: #{fault_code}]: #{fault_description}")
    end
  end

  # non-200 response without a SOAP fault
  class WinRMHTTPTransportError < WinRMError
    attr_reader :status_code

    def initialize(msg, status_code)
      @status_code = status_code
      super(msg + " (#{status_code}).")
    end
  end
end
