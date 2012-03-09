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

require 'date'
require 'kconv' if(RUBY_VERSION.start_with? '1.9') # bug in rubyntlm with ruby 1.9.x
require 'logging'

module WinRM
  Logging.logger.root.level = :info
  Logging.logger.root.appenders = Logging.appenders.stdout
end

require 'winrm/helpers/iso8601_duration'
require 'winrm/soap_provider'
