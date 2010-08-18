#############################################################################
# Copyright © 2010 Dan Wanek <dan.wanek@gmail.com>
#
#
# This file is part of WinRM.
# 
# WinRM is free software: you can redistribute it and/or
# modify it under the terms of the GNU General Public License as published
# by the Free Software Foundation, either version 3 of the License, or (at
# your option) any later version.
# 
# WinRM is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General
# Public License for more details.
# 
# You should have received a copy of the GNU General Public License along
# with WinRM.  If not, see <http://www.gnu.org/licenses/>.
#############################################################################
require 'handsoap'

module WinRM
  module SOAP
    NS_ADDRESSING  ='a'   # http://schemas.xmlsoap.org/ws/2004/08/addressing
    NS_CIMBINDING  ='b'   # http://schemas.dmtf.org/wbem/wsman/1/cimbinding.xsd
    NS_ENUM        ='n'   # http://schemas.xmlsoap.org/ws/2004/09/enumeration
    NS_TRANSFER    ='x'   # http://schemas.xmlsoap.org/ws/2004/09/transfer
    NS_WSMAN_DMTF  ='w'   # http://schemas.dmtf.org/wbem/wsman/1/wsman.xsd
    NS_WSMAN_MSFT  ='p'   # http://schemas.microsoft.com/wbem/wsman/1/wsman.xsd
    NS_SCHEMA_INST ='xsi' # http://www.w3.org/2001/XMLSchema-instance
    NS_WIN_SHELL   ='rsp' # http://schemas.microsoft.com/wbem/wsman/1/windows/shell
  end
end

require 'soap/winrm_service'
