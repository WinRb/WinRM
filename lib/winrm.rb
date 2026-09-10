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

require 'logger'
require_relative 'winrm/version'
require_relative 'winrm/connection'
require_relative 'winrm/exceptions'

# Main WinRM module entry point
module WinRM
  LOG_LEVELS = %w[debug info warn error fatal].freeze

  # Default log level used by WinRM loggers, controlled by the
  # WINRM_LOG environment variable. Falls back to :warn when unset
  # or invalid.
  # @return [Symbol] One of :debug, :info, :warn, :error or :fatal
  def self.default_log_level
    level = ENV.fetch('WINRM_LOG', '').downcase
    return :warn if level.empty?

    unless LOG_LEVELS.include?(level)
      warn "Invalid WINRM_LOG level is set: #{ENV.fetch('WINRM_LOG', nil)}"
      warn ''
      warn 'Please use one of the standard log levels: ' \
        'debug, info, warn, or error'
      return :warn
    end

    level.to_sym
  end
end
