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

require_relative 'pushy_client/version'
require_relative 'pushy_client/heartbeater'
require_relative 'pushy_client/job_runner'
require_relative 'pushy_client/protocol_handler'
require_relative 'pushy_client/periodic_reconfigurer'
require_relative 'pushy_client/whitelist'
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
    @file_dir        = options[:file_dir] || '/tmp/pushy'
    @file_dir_expiry = options[:file_dir_expiry] || 86400

    @allow_unencrypted = options[:allow_unencrypted] || false
    @client_curve_pub_key, @client_curve_sec_key = ZMQ::Util.curve_keypair

    Chef::Log.info("[#{@node_name}] using config file path: '#{Chef::Config[:config_file]}'")

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
    @file_dir_cleaner = FileDirCleaner.new(self)

    @reconfigure_lock = Mutex.new

    Chef::Log.info "[#{node_name}] Using node name: #{node_name}"
    Chef::Log.info "[#{node_name}] Using org name: #{org_name}"
    Chef::Log.info "[#{node_name}] Using Chef server: #{chef_server_url}"
    Chef::Log.info "[#{node_name}] Using private key: #{client_key}"
    Chef::Log.info "[#{node_name}] Incarnation ID: #{incarnation_id}"
    Chef::Log.info "[#{node_name}] Allowing fallback to unencrypted connection: #{allow_unencrypted}"
  end

  attr_accessor :chef_server_url
  attr_accessor :client_name
  attr_accessor :client_key
  attr_accessor :org_name
  attr_accessor :node_name
  attr_accessor :hostname
  attr_accessor :whitelist
  attr_reader :incarnation_id
  attr_reader :legacy_mode # indicate we've fallen back to 1.x

  # crypto
  attr_reader :client_curve_pub_key
  attr_reader :client_curve_sec_key
  attr_reader :allow_unencrypted
  attr_reader :using_curve

  #
  attr_reader :file_dir
  attr_reader :file_dir_expiry

  attr_reader :config

  def start
    Chef::Log.info "[#{node_name}] Starting client ..."

    @config = get_config

    @job_runner.start
    @protocol_handler.start
    @heartbeater.start
    @periodic_reconfigurer.start
    @file_dir_cleaner.start

    Chef::Log.info "[#{node_name}] Started client."
  end

  def stop
    Chef::Log.info "[#{node_name}] Stopping client ..."

    @job_runner.stop
    @protocol_handler.stop
    @heartbeater.stop
    @periodic_reconfigurer.stop
    @file_dir_cleaner.stop

    Chef::Log.info "[#{node_name}] Stopped client."
  end

  def reconfigure
    first = true
    while !@job_runner.safe_to_reconfigure? do
      Chef::Log.info "[#{node_name}] Job in flight, delaying reconfigure" if first
      first = false
      sleep 5
    end

    @reconfigure_lock.synchronize do
      Chef::Log.info "[#{node_name}] Reconfiguring client / reloading keys ..."

      @config = get_config

      @job_runner.reconfigure
      @protocol_handler.reconfigure
      @heartbeater.reconfigure
      @periodic_reconfigurer.reconfigure

      Chef::Log.info "[#{node_name}] Reconfigured client."
    end
    trigger_gc
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

  def trigger_gc
    # We have a tendency to bloat up because GCs aren't forced; this tries to keep things a little bit saner.
    before_stat = GC.stat()
    GC.start()
    after_stat = GC.stat()
    stat = :count
    delta = after_stat[stat] - before_stat[stat]
    Chef::Log.info("[#{node_name}] Forced GC; Stat #{stat} changed #{delta}")
  end

  def job_state
    @job_runner.job_state
  end

  def send_command(command, job_id, params = {})
    @protocol_handler.send_command(command, job_id, params)
  end

  def send_heartbeat(sequence)
    @protocol_handler.send_heartbeat(sequence)
  end

  def commit(job_id, command, opts)
    @job_runner.commit(job_id, command, opts)
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
    @rest ||= Chef::ServerAPI.new(chef_server_url, client_name: client_name, signing_key_filename: client_key)
  end

  def get_config
    resource = "/pushy/config/#{node_name}"

    Chef::Log.info "[#{node_name}] Retrieving configuration from #{chef_server_url}/#{resource}: ..."
    esc_key = CGI::escape(@client_curve_pub_key)
    version = PushyClient::PROTOCOL_VERSION
    resource = "pushy/config/#{node_name}?ccpk=#{esc_key}&version=#{version}"

    config = rest.get(resource)

    if config.has_key?("curve_public_key")
    # Version 2.0  or greater, we should use encryption
      @using_curve = true
      @legacy_mode = false
    elsif allow_unencrypted then
      @using_curve = false
      @legacy_mode = true
      Chef::Log.info "[#{node_name}] No key returned from server; falling back to 1.x protocol (no encryption)"
    else
      msg = "[#{node_name}] Exiting: No key returned from server; server may be using 1.x protocol. The config flag 'allow_unencrypted' disables encryption and allows use of 1.x server. Use with caution!"
      Chef::Log.error msg
      Kernel.abort msg
      config = nil
    end
    return config
  end

  # XXX Should go in a separate file
  class FileDirCleaner
    def initialize(client)
      @client = client
      @expiration_time = client.file_dir_expiry
      @file_dir = client.file_dir
    end

    def start
      @thread = Thread.new { expiration_loop }
    end

    def stop
      @thread.kill
    end

    private

    def expiration_loop
      while true do
        files = Dir.glob(@file_dir + "/pushy_file*")
        now = Time.now
        old_files = files.select { |f| now - File.mtime(f) > @expiration_time}
        File.delete(*old_files)
        sleep @expiration_time
      end
    end
  end
end
