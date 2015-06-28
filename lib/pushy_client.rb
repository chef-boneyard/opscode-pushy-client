#
# Author:: John Keiser (<jkeiser@opscode.com>)
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

require 'pushy_client/heartbeater'
require 'pushy_client/job_runner'
require 'pushy_client/protocol_handler'
require 'pushy_client/periodic_reconfigurer'
require 'pushy_client/whitelist'
require 'ohai'
require 'uuidtools'
require 'ffi-rzmq'
require 'cgi'

class PushyClient
  def initialize(options)
    @chef_server_url = options[:chef_server_url]
    @client_name     = options[:client_name] || options[:node_name]
    @client_key      = options[:client_key]
    @node_name       = options[:node_name]
    @whitelist       = PushyClient::Whitelist.new(options[:whitelist])
    @hostname        = options[:hostname]
    @client_curve_pub_key, @client_curve_sec_key = ZMQ::Util.curve_keypair

    if @chef_server_url =~ /\/organizations\/+([^\/]+)\/*/
      @org_name = $1
    else
      raise "chef_server must end in /organizations/ORG_NAME"
    end

    @incarnation_id = UUIDTools::UUID.random_create

    # State is global and persists across stops and starts
    @job_runner = JobRunner.new(self)
    @heartbeater = Heartbeater.new(self)
    @protocol_handler = ProtocolHandler.new(self)
    @periodic_reconfigurer = PeriodicReconfigurer.new(self)

    @reconfigure_lock = Mutex.new

    Chef::Log.info "[#{node_name}] Using node name: #{node_name}"
    Chef::Log.info "[#{node_name}] Using Chef server: #{chef_server_url}"
    Chef::Log.info "[#{node_name}] Using private key: #{client_key}"
    Chef::Log.info "[#{node_name}] Using org name: #{org_name}"
    Chef::Log.info "[#{node_name}] Incarnation ID: #{incarnation_id}"
  end

  attr_accessor :chef_server_url
  attr_accessor :client_name
  attr_accessor :client_key
  attr_accessor :org_name
  attr_accessor :node_name
  attr_accessor :hostname
  attr_accessor :whitelist
  attr_reader :incarnation_id
  attr_reader :client_curve_pub_key
  attr_reader :client_curve_sec_key

  attr_reader :config

  def start
    Chef::Log.info "[#{node_name}] Starting client ..."

    @config = get_config

    @job_runner.start
    @protocol_handler.start
    @heartbeater.start
    @periodic_reconfigurer.start

    Chef::Log.info "[#{node_name}] Started client."
  end

  def stop
    Chef::Log.info "[#{node_name}] Stopping client ..."

    @job_runner.stop
    @protocol_handler.stop
    @heartbeater.stop
    @periodic_reconfigurer.stop

    Chef::Log.info "[#{node_name}] Stopped client."
  end

  def reconfigure
    @reconfigure_lock.synchronize do
      Chef::Log.info "[#{node_name}] Reconfiguring client / reloading keys ..."

      @config = get_config

      @job_runner.reconfigure
      @protocol_handler.reconfigure
      @heartbeater.reconfigure
      @periodic_reconfigurer.reconfigure

      Chef::Log.info "[#{node_name}] Reconfigured client."
    end
  end

  def trigger_reconfigure
    # Many of the threads triggering a reconfigure will get destroyed DURING
    # a reconfigure, so we need to spawn a separate thread to take care of it.
    Thread.new do
      begin
        reconfigure
      rescue
        log_exception("Error reconfiguring", $!)
      end
    end
  end

  def job_state
    @job_runner.job_state
  end

  def send_command(command, job_id)
    @protocol_handler.send_command(command, job_id)
  end

  def send_heartbeat(sequence)
    @protocol_handler.send_heartbeat(sequence)
  end

  def commit(job_id, command)
    @job_runner.commit(job_id, command)
  end

  def run(job_id)
    @job_runner.run(job_id)
  end

  def abort
    @job_runner.abort
  end

  def heartbeat_received(incarnation_id, sequence)
    @heartbeater.heartbeat_received(incarnation_id, sequence)
  end

  def log_exception(message, exception)
    Chef::Log.error("[#{node_name}] #{message}: #{exception}\n#{exception.backtrace.join("\n")}")
  end

  def on_server_availability_change(&block)
    @heartbeater.on_server_availability_change(&block)
  end

  def online?
    @heartbeater.online?
  end

  def on_job_state_change(&block)
    @job_runner.on_job_state_change(&block)
  end

  private

  def rest
    @rest ||= Chef::REST.new(chef_server_url, client_name, client_key)
  end

  def get_config
    Chef::Log.info "[#{node_name}] Retrieving configuration from #{chef_server_url}/pushy/config/#{node_name} ..."
    esc_key = CGI::escape(@client_curve_pub_key)
    rest.get_rest("pushy/config/#{node_name}?ccpk=#{esc_key}", false)
  end
end
