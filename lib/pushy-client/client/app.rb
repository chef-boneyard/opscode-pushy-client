#
# Author:: James Casey (<james@opscode.com>)
# Author:: Mark Anderson (<mark@opscode.com>)
# Author:: John Keiser (<john@opscode.com>)
# Copyright:: Copyright (c) 2012 Opscode, Inc.
# License:: Apache License, Version 2.0
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

require 'chef/rest'
require 'time'
require 'pp'

module PushyClient
  class App
    DEFAULT_SERVICE_URL_BASE = "https://localhost/organization/clownco"

    attr_accessor :service_url_base
    attr_accessor :client_private_key_path
    attr_accessor :node_name

    attr_accessor :reaper, :worker


    def initialize(options)
      @service_url_base        = options[:service_url_base]
      @client_private_key_path = options[:client_private_key_path]
      @node_name               = options[:node_name]

      PushyClient::Log.info "[#{node_name}] Using configuration endpoint: #{service_url_base}"
      PushyClient::Log.info "[#{node_name}] Using private key: #{client_private_key_path}"
      PushyClient::Log.info "[#{node_name}] Using node name: #{node_name}"
    end

    def get_rest(path, raw)
      @rest_endpoint ||= Chef::REST.new(service_url_base || DEFAULT_SERVICE_URL_BASE,
                                        node_name,
                                        client_private_key_path)
      @rest_endpoint.get_rest(path, raw)
    end

    def start
      PushyClient::Log.info "[#{node_name}] Booting ..."

      EM.run do
        begin
          start_worker
        rescue Exception => e
          PushyClient::Log.error "[#{node_name}] Exception #{e.message}"
          PushyClient::Log.error "[#{node_name}] #{e.backtrace.inspect}"
        end
      end

    end

    def stop
      PushyClient::Log.info "[#{node_name}] Stopping client ..."
      worker.stop
      PushyClient::Log.info "[#{node_name}] Stopped."
    end

    def reload
      worker.stop
      start_worker
    end

    def start_worker
      self.worker = PushyClient::Worker.load!(self).tap(&:start)
      self.reaper = PushyClient::Reaper.watch! :app => self, :lifetime => worker.lifetime
    end

  end
end
