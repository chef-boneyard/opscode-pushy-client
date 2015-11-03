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
    def initialize(client)
      @client = client
    end

    attr_reader :client
    attr_reader :lifetime

    def node_name
      client.node_name
    end

    def start
      @lifetime = client.config['lifetime']
      prng = Random.new
      @reconfigure_thread = Thread.new do
        Chef::Log.info "[#{node_name}] Starting reconfigure thread.  Will reconfigure / reload keys after #{@lifetime} seconds, less up to splay #{SPLAY}."
        while true
          begin
            @delay = @lifetime * (1 - prng.rand(SPLAY))
            sleep(@delay)
            Chef::Log.info "[#{node_name}] Config is now #{@delay} seconds old.  Reconfiguring / reloading keys ..."
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
