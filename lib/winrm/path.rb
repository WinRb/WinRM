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

module WinRM
  # Mangaes cross platform paths
  class Path
    attr_reader :original_path
    # New Path
    # @param path [String] the file system path
    def initialize(path)
      @original_path = path
    end

    # Converts to a unix path (with /)
    # @return [String] the unix path
    def unix_path
      u = ''
      u << "#{root}:/" if rooted?
      u << '//' if unc?
      u << leaf.gsub(/^[\/*]/,'')
    end

    # Converts to a windows path (with \)
    # @return [String] the unix path
    def windows_path
      unix_path.gsub('/',"\\")
    end

    # Dobule escapes the \ in the windows path
    # @return [String] the double escaped windows path
    def double_escaped_windows_path
      windows_path.gsub("\\","\\\\\\\\")
    end

    # Checks if the path is a UNC share path
    # @return [Boolean]
    def unc?
      @original_path =~ /^\\\\/ ? true : false
    end

    # Checks if the path is a relative share path
    # @return [Boolean]
    def relative?
      not ( rooted? or unc? )
    end

    # Normalizes the path removing duplicate and mismatched path information
    # @return [String] The normalized path
    def normalize
      normal = @original_path.dup
      normal = normal.gsub(/\\{1,}|\/{1,}/,'/').gsub(/\/{1,}$/,'').gsub(/^\/{1,}/,'')
      normal
    end

    # Gets the root "Drive" of the path
    # @return [String] The drive letter at the root of the path
    def root
      normal = normalize
      if normal.size.eql?(2) and normal =~ /\w:/
        return normal[0]
      else
        p = normal.split(':',2)
        return p.count.eql?(2) ? p[0] : nil
      end
    end

    # Checks if the path is a rooted path
    # @return [Boolean]
    def rooted?
      not root.nil?
    end

    # Gets the leaf node of a relative or rooted path
    # @return [String] The lead node
    def leaf
      p = normalize.split(':',2)
      return p.count.eql?(2) ? p[1] : p[0]
    end

    def basename
      File.basename(normalize)
    end

    def dirname
      File.dirname(normalize)
    end


  end
end