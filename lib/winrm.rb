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

# We only what one instance of this class so include Singleton
require 'date'
require 'kconv' if(RUBY_VERSION.start_with? '1.9') # bug in rubyntlm with ruby 1.9.x

require 'winrm/helpers/iso8601_duration'
require 'winrm/soap_provider'
