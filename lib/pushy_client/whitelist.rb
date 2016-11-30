# @copyright Copyright 2014 Chef Software, Inc. All Rights Reserved.
#
# This file is provided to you under the Apache License,
# Version 2.0 (the "License"); you may not use this file
# except in compliance with the License. You may obtain
# a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing,
# software distributed under the License is distributed on an
# "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
# KIND, either express or implied. See the License for the
# specific language governing permissions and limitations
# under the License.
#

require "chef/log"

class PushyClient
  class Whitelist

    attr_accessor :whitelist

    def initialize(whitelist)
      @whitelist = whitelist
    end

    def [](argument)
      command = process(argument)
      node_name = "UNKNOWN"
      job_id = "UNKNOWN"
      Chef::Log.info("[#{node_name}] Job #{job_id}: whitelist '#{argument}' to '#{command}'")
      command
    end

    def process(argument)
      # If we have an exact match, use it
      if whitelist.has_key?(argument)
        return whitelist[argument]
      else
        whitelist.keys.each do |key|
          if key.kind_of?(Regexp)
            if key.match(argument)
              value = whitelist[key]
              if value.kind_of?(Hash)
                # Need a deep copy, don't want to change the global value
                new_value = Marshal.load(Marshal.dump(value))
                new_value[:command_line] = argument.gsub(key, value[:command_line])
                return new_value
              else
                return argument.gsub(key, value)
              end
            end
          end
        end
      end

      nil
    end

    def method_missing(method, *args, &block)
      @whitelist.send(method, *args, &block)
    end
  end
end
