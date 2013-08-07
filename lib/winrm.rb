# Licensed to the Apache Software Foundation (ASF) under one
# or more contributor license agreements.  See the NOTICE file
# distributed with this work for additional information
# regarding copyright ownership.  The ASF licenses this file
# to you under the Apache License, Version 2.0 (the
# "License"); you may not use this file except in compliance
# with the License.  You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing,
# software distributed under the License is distributed on an
# "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
# KIND, either express or implied.  See the License for the
# specific language governing permissions and limitations
# under the License.
require 'active_support/core_ext/kernel'
case RbConfig::CONFIG['host_os']
when /mswin|msys|mingw|cygwin|bccwin|wince|emc/
  begin
    require 'rubysspi'
  rescue LoadError
    warn 'WARNING: rubysspi gem is missing. Kerberos authentication will not work'
  end
when /darwin|mac os/
  begin
    # We turn of warnings because we know that OSX is missing some gssapi features, but
    # we don't care
    silence_warnings do
      require 'gssapi/heimdal'
      require 'gssapi'
    end
  rescue LoadError
    warn 'WARNING: gssapi gem is missing. Kerberos authentication will not work'
  end
else
  begin
    require 'gssapi'
  rescue LoadError
    warn 'WARNING: gssapi gem is missing. Kerberos authentication will not work'
  end
end

require 'date'
require 'logger'
require 'httpclient'
require 'nori'
require 'uuidtools'
require 'base64'
require 'nokogiri'
require 'gyoku'
require 'ruby-duration'


module WinRM

  NS_SOAP_ENV    ='s'   # http://www.w3.org/2003/05/soap-envelope
  NS_ADDRESSING  ='a'   # http://schemas.xmlsoap.org/ws/2004/08/addressing
  NS_CIMBINDING  ='b'   # http://schemas.dmtf.org/wbem/wsman/1/cimbinding.xsd
  NS_ENUM        ='n'   # http://schemas.xmlsoap.org/ws/2004/09/enumeration
  NS_TRANSFER    ='x'   # http://schemas.xmlsoap.org/ws/2004/09/transfer
  NS_WSMAN_DMTF  ='w'   # http://schemas.dmtf.org/wbem/wsman/1/wsman.xsd
  NS_WSMAN_MSFT  ='p'   # http://schemas.microsoft.com/wbem/wsman/1/wsman.xsd
  NS_SCHEMA_INST ='xsi' # http://www.w3.org/2001/XMLSchema-instance
  NS_WIN_SHELL   ='rsp' # http://schemas.microsoft.com/wbem/wsman/1/windows/shell
  NS_WSMAN_FAULT = 'f'  # http://schemas.microsoft.com/wbem/wsman/1/wsmanfault
  NS_WSMAN_CONF  = 'cfg'# http://schemas.microsoft.com/wbem/wsman/1/config

  NAMESPACES =  { 'xmlns:a' => 'http://schemas.xmlsoap.org/ws/2004/08/addressing',
                      'xmlns:b' => 'http://schemas.dmtf.org/wbem/wsman/1/cimbinding.xsd',
                      'xmlns:n' => 'http://schemas.xmlsoap.org/ws/2004/09/enumeration',
                      'xmlns:x' => 'http://schemas.xmlsoap.org/ws/2004/09/transfer',
                      'xmlns:w' => 'http://schemas.dmtf.org/wbem/wsman/1/wsman.xsd',
                      'xmlns:p' => 'http://schemas.microsoft.com/wbem/wsman/1/wsman.xsd',
                      'xmlns:cfg' => 'http://schemas.microsoft.com/wbem/wsman/1/config',
                      'xmlns:xsd' => 'http://www.w3.org/2001/XMLSchema',
                      'xmlns:xsi' => 'http://www.w3.org/2001/XMLSchema-instance',
                      'xmlns:rsp' => 'http://schemas.microsoft.com/wbem/wsman/1/windows/shell',
                      'xmlns:s' => 'http://www.w3.org/2003/05/soap-envelope',
                      'xmlns:f'   => 'http://schemas.microsoft.com/wbem/wsman/1/wsmanfault'
                    }.freeze

  class << self

    def logger
      @logger ||= ::Logger.new(STDOUT)
    end

    attr_writer :logger
    alias :log :logger
     
  end

  ENV['WINRM_LOG'] ||= 'INFO'
  WinRM.logger.level = Logger.const_get(ENV['WINRM_LOG'])
  if WinRM.logger.level == Logger::DEBUG
    $DEBUG = true
  end
  
  require 'winrm/path'
  require 'winrm/mixins/wmi_enumeration'
  require 'winrm/client'
  require 'winrm/file_manager'
  require 'winrm/headers'
  require 'winrm/request/base'
  require 'winrm/request/open_shell'
  require 'winrm/request/close_shell'
  require 'winrm/request/start_process'
  require 'winrm/request/read_output_streams'
  require 'winrm/request/write_stdin'
  require 'winrm/request/close_command'
  require 'winrm/request/wql'
  require 'winrm/request/invoke_wmi'
  require 'winrm/request/enumerate'
  require 'winrm/exceptions'

  

end

