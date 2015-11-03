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

# This is needed to fix an issue in win32-process v. 0.6.5
# where Process.wait blocks the entire Ruby interpreter
# for the duration of the process.
require 'chef/platform'
if Chef::Platform.windows?
  require 'pushy_client/win32'
end

class PushyClient
  class JobRunner
    def initialize(client)
      @client = client
      @on_job_state_change = []

      set_job_state(:idle)
      @pid = nil
      @process_thread = nil

      # Keep job state and process state in sync
      @state_lock = Mutex.new
    end

    attr_reader :client
    attr_reader :state
    attr_reader :job_id
    attr_reader :command
    attr_reader :lockfile

    def safe_to_reconfigure?
      @state_lock.synchronize do
        @state == :idle
      end
    end

    def node_name
      client.node_name
    end

    def start
    end

    def stop
      if @state == :running
        kill_process
      end
      set_job_state(:idle)
    end

    def reconfigure
      # We have no configuration, and keep state between reconfigures
    end

    def commit(job_id, command)
      @state_lock.synchronize do
        if @state == :idle
          # If we're being asked to lock
          if client.whitelist[command] &&
             client.whitelist[command].is_a?(Hash) &&
             client.whitelist[command][:lock]
            # If the command is chef-client
            # We don't want to run if there is already another instance of chef-client going,
            # so we check to see if there is a runlock on chef-client before committing. This
            # currently only works in versions of chef where runlock has been implemented.

            # The location of our lockfile
            if client.whitelist[command][:lock] == true
              lockfile_location = Chef::Config[:lockfile] || "#{Chef::Config[:file_cache_path]}/chef-client-running.pid"
            else
              lockfile_location = client.whitelist[command][:lock]
            end
            # Open the Lockfile
            begin
              @lockfile = File.open(lockfile_location, 'w')
              locked = lockfile.flock(File::LOCK_EX|File::LOCK_NB)
              unless locked
                Chef::Log.info("[#{node_name}] Received commit #{job_id} but is already running '#{command}'")
                client.send_command(:nack_commit, job_id)
                return false
              end
            rescue Errno::ENOENT
            end
          elsif client.whitelist[command]
            Chef::Log.info("[#{node_name}] Received commit #{job_id}")
            set_job_state(:committed, job_id, command)
            client.send_command(:ack_commit, job_id)
            true
          else
            Chef::Log.error("[#{node_name}] Received commit #{job_id}, but command '#{command}' is not in the whitelist!")
            client.send_command(:nack_commit, job_id)
            false
          end
        else
          Chef::Log.warn("[#{node_name}] Received commit #{job_id} but current state is #{@state} #{@job_id}")
          client.send_command(:nack_commit, job_id)
          false
        end
      end
    end

    def run(job_id)
      @state_lock.synchronize do
        if @state == :committed && @job_id == job_id
          Chef::Log.info("[#{node_name}] Received run #{job_id}")
          pid, process_thread = start_process
          set_job_state(:running, job_id, @command, pid, process_thread)
          client.send_command(:ack_run, job_id)
          true
        else
          Chef::Log.warn("[#{node_name}] Received run #{job_id} but current state is #{@state} #{@job_id}")
          client.send_command(:nack_run, job_id)
          false
        end
      end
    end

    def abort
      Chef::Log.info("[#{node_name}] Received abort")
      @state_lock.synchronize do
        _job_id = job_id
        stop
        client.send_command(:aborted, _job_id)
      end
    end

    def job_state
      @state_lock.synchronize do
        get_job_state
      end
    end

    def on_job_state_change(&block)
      @on_job_state_change << block
    end

    private

    def get_job_state
      {
        :state => @state,
        :job_id => @job_id,
        :command => @command
      }
    end

    def set_job_state(state, job_id = nil, command = nil, pid = nil, process_thread = nil)
      if state == :idle || state == :running
        if @lockfile
          # If there is a lockfile Release the lock to allow chef-client to run
          lockfile.flock(File::LOCK_UN)
          lockfile.close
        end
      end
      @state = state
      @job_id = job_id
      @command = command
      @pid = pid
      @process_thread = process_thread

      # Notify people of the change
      @on_job_state_change.each { |block| block.call(get_job_state) }
    end

    def completed(job_id, exit_code)
      Chef::Log.info("[#{node_name}] Job #{job_id} completed with exit code #{exit_code}")
      @state_lock.synchronize do
        if @state == :running && @job_id == job_id
          set_job_state(:idle)
          status = exit_code == 0 ? :succeeded : :failed
          client.send_command(status, job_id)
        end
      end
    end

    def start_process
      # _pid and _job_id are local variables so that if @pid or @job_id change
      # for any reason (for example, they become nil), the thread we create
      # still tracks the correct pid.
      if client.whitelist[command].is_a?(Hash)
        command_line = client.whitelist[command][:command_line]
      else
        command_line = client.whitelist[command]
      end
      _pid = Process.spawn({'PUSHY_NODE_NAME' => node_name}, command_line)
      _job_id = @job_id
      Chef::Log.info("[#{node_name}] Job #{job_id}: started command '#{command_line}' with PID '#{_pid}'")

      # Wait for the job to complete and close it out.
      process_thread = Thread.new do
        begin
          pid, exit_code = Process.waitpid2(_pid)
          completed(_job_id, exit_code)
        rescue
          client.log_exception("Exception raised while waiting for job #{_job_id} to complete", $!)
          abort
        end
      end

      [ _pid, process_thread ]
    end

    def kill_process
      Chef::Log.info("[#{node_name}] Killing process #{@pid}")
      @process_thread.kill
      @process_thread.join
      begin
        Process.kill(1, @pid)
      rescue
        client.log_exception("Exception in Process.kill(1, #{@pid})", $!)
      end
    end
  end
end
