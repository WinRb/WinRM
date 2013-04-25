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

module Iso8601Duration

  # Convert the number of seconds to an ISO8601 duration format
  # @see http://tools.ietf.org/html/rfc2445#section-4.3.6
  # @param [Fixnum] seconds The amount of seconds for this duration
  def self.sec_to_dur(seconds)
    seconds = seconds.to_i
    iso_str = "P"
    if(seconds >= 604800) # more than a week
      weeks = seconds / 604800
      seconds -= (604800 * weeks)
      iso_str << "#{weeks}W"
    end
    if(seconds >= 86400) # more than a day
      days = seconds / 86400
      seconds -= (86400 * days)
      iso_str << "#{days}D"
    end
    if(seconds > 0)
      iso_str << "T"
      if(seconds > 3600) # more than an hour
        hours = seconds / 3600
        seconds -= (3600 * hours)
        iso_str << "#{hours}H"
      end
      if(seconds > 60) # more than a minute
        minutes = seconds / 60
        seconds -= (60 * minutes)
        iso_str << "#{minutes}M"
      end
      iso_str << "#{seconds}S" unless seconds.eql? 0
    end

    iso_str
  end
end
