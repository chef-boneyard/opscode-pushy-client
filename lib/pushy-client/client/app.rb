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

    attr_accessor :service_url_base
    attr_accessor :client_private_key_path
    attr_accessor :org_name
    attr_accessor :node_name

    attr_accessor :reaper, :worker


    def initialize(options)
      @service_url_base        = options[:service_url_base]
      @client_private_key_path = options[:client_private_key_path]
      @node_name               = options[:node_name]

      if @service_url_base =~ /\/organizations\/+([^\/]+)\/*/
        @org_name = $1
      else
        raise "chef_server must end in /organizations/ORG_NAME"
      end

      Chef::Log.info "[#{node_name}] Using configuration endpoint: #{service_url_base}"
      Chef::Log.info "[#{node_name}] Using private key: #{client_private_key_path}"
      Chef::Log.info "[#{org_name}] Using org name: #{org_name}"
      Chef::Log.info "[#{node_name}] Using node name: #{node_name}"
    end

    def get_rest(path, raw)
      @rest_endpoint ||= Chef::REST.new(service_url_base,
                                        node_name,
                                        client_private_key_path)
      @rest_endpoint.get_rest(path, raw)
    end

    def start
      Chef::Log.info "[#{node_name}] Booting ..."

      EM.error_handler do |err|
        Chef::Log.error "Exception in EM handler: #{err}"
      end

      EM.run do
        begin
          start_worker
        rescue Exception => e
          Chef::Log.error "[#{node_name}] Exception #{e.message}"
          Chef::Log.error "[#{node_name}] #{e.backtrace.inspect}"
        end
      end

    end

    def stop
      Chef::Log.info "[#{node_name}] Stopping client ..."
      worker.stop
      Chef::Log.info "[#{node_name}] Stopped."
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
