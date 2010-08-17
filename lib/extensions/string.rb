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

# Custom extensions to the class String
class String
  # Change CamelCased strings to ruby_cased strings
  # It uses the lookahead assertion ?=  In this case it basically says match
  # anything followed by a capital letter, but not the capital letter itself.
  # @see http://www.pcre.org/pcre.txt The PCRE guide for more details
  def ruby_case
    self.split(/(?=[A-Z])/).join('_').downcase
  end

  # Change a ruby_cased string to CamelCased
  def camel_case
    self.split(/_/).map { |i|
      i.sub(/^./) { |s| s.upcase }
    }.join
  end
end # String
