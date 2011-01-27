# Format an ISO8601 Duration
module Iso8601Duration

  # Convert the number of seconds to an ISO8601 duration format
  # @see http://tools.ietf.org/html/rfc2445#section-4.3.6
  # @param [Fixnum] seconds The amount of seconds for this duration
  def self.sec_to_dur(seconds)
    seconds = seconds.to_i
    iso_str = "P"
    if(seconds > 604800) # more than a week
      weeks = seconds / 604800
      seconds -= (604800 * weeks)
      iso_str << "#{weeks}W"
    end
    if(seconds > 86400) # more than a day
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
      iso_str << "#{seconds}S"
    end

    iso_str
  end
end
