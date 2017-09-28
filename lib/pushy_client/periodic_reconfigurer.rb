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

class PushyClient
  class PeriodicReconfigurer
    SPLAY = 0.10
    POLL_INTERVAL = 5 # seconds
    
    def initialize(client)
      @prng = Random.new
      @client = client
      @lock = Mutex.new
      @reconfigure_deadline = nil
    end

    attr_reader :client
    attr_reader :lifetime

    def node_name
      client.node_name
    end

    def reconfigure_deadline
      @lock.synchronize do
        @reconfigure_deadline
      end
    end
    
    # set the reconfigure deadline to some future number of seconds (with a splay applied)
    def update_reconfigure_deadline(delay)
      @lock.synchronize do
        @reconfigure_deadline = Time.now + delay * (1 - @prng.rand(SPLAY))
        Chef::Log.info "[#{node_name}] Setting reconfigure deadline to #{@reconfigure_deadline}"
      end
    end
    
    def start
      @lifetime = client.config['lifetime']

      @reconfigure_thread = Thread.new do
        Chef::Log.info "[#{node_name}] Starting reconfigure thread.  Will reconfigure / reload keys after #{@lifetime} seconds, less up to splay #{SPLAY}."
        while true
          begin
            update_reconfigure_deadline(@lifetime)
            while Time.now < reconfigure_deadline do
              # could also check the config file for updates here and
              # resolve a long standing wishlist item from customers.
              sleep(POLL_INTERVAL)
            end
            Chef::Log.info "[#{node_name}] Reconfigure deadline of #{reconfigure_deadline} is now past. Reconfiguring / reloading keys ..."
            client.trigger_reconfigure
          rescue
            client.log_exception("Error in reconfigure thread", $!)
          end
        end
      end
    end

    def stop
      Chef::Log.info "[#{node_name}] Stopping reconfigure thread ..."
      @reconfigure_thread.kill
      @reconfigure_thread.join
      @reconfigure_thread = nil
    end

    def reconfigure
      stop
      start
    end
  end
end
