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
  class Heartbeater
    NUM_HEARTBEATS_TO_LOG = 3

    def initialize(client)
      @client = client
      @online_mutex = Mutex.new
      @heartbeat_sequence = 1
      @on_server_availability_change = []
    end

    attr_reader :client
    attr_reader :incarnation_id
    attr_reader :online_threshold
    attr_reader :offline_threshold
    attr_reader :interval

    def node_name
      client.node_name
    end

    def online?
      @online
    end

    def on_server_availability_change(&block)
      @on_server_availability_change << block
    end

    def start
      @incarnation_id = client.config['incarnation_id']
      @online_threshold = client.config['push_jobs']['heartbeat']['online_threshold']
      @offline_threshold = client.config['push_jobs']['heartbeat']['offline_threshold']
      @interval = client.config['push_jobs']['heartbeat']['interval']

      @online_counter = 0
      @offline_counter = 0
      # We optimistically declare the server online since we just got a config blob via http from it
      # however, if the server is reachable via http but not zmq we'll go down after a few heartbeats.
      set_online(true)

      @heartbeat_thread = Thread.new do
        Chef::Log.info "[#{node_name}] Starting heartbeat / offline detection thread on interval #{interval} ..."

        while true
          begin
            # When the server goes more than <offline_threshold> intervals
            # without sending us a heartbeat, treat it as offline
            @online_mutex.synchronize do
              if @online
                if @offline_counter > offline_threshold
                  Chef::Log.info "[#{node_name}] Server has missed #{@offline_counter} heartbeats in a row.  Considering it offline, and stopping heartbeat."
                  set_online(false)
                  @online_counter = 0
                else
                  @offline_counter += 1
                end
              end
            end

            # We only send heartbeats to online servers
            if @online
              client.send_heartbeat(@heartbeat_sequence)
              if @heartbeat_sequence <= NUM_HEARTBEATS_TO_LOG
                Chef::Log.info "[#{node_name}] Sending heartbeat #{@heartbeat_sequence} (logging first #{NUM_HEARTBEATS_TO_LOG})"
              else
                Chef::Log.debug "[#{node_name}] Sending heartbeat #{@heartbeat_sequence}"
              end
              @heartbeat_sequence += 1
            end
            sleep(interval)
          rescue
            client.log_exception("Error in heartbeat / offline detection thread", $!)
          end
        end
      end
    end

    def stop
      Chef::Log.info "[#{node_name}] Stopping heartbeat / offline detection thread ..."
      @heartbeat_thread.kill
      @heartbeat_thread.join
    end

    def reconfigure
      stop
      start # Start picks up new configuration
    end

    # TODO use the sequence for something?
    def heartbeat_received(incarnation_id, sequence)
      message = "[#{node_name}] Received server heartbeat (sequence ##{sequence})"
      if @online_counter <= NUM_HEARTBEATS_TO_LOG
        Chef::Log.info message + " logging #{@online_counter}/#{NUM_HEARTBEATS_TO_LOG}"
      else
        Chef::Log.debug message
      end
      # If the incarnation id has changed, we need to reconfigure.
      if @incarnation_id != incarnation_id
        if @incarnation_id.nil?
          @incarnation_id = incarnation_id
          Chef::Log.info "[#{node_name}] First heartbeat received.  Server is at incarnation ID #{incarnation_id}."
        else
          # We need to set incarnation id before we reconfigure; this thread will
          # be killed by the reconfigure :)
          splay = Random.new.rand(interval.to_f)
          Chef::Log.info "[#{node_name}] Server restart detected (incarnation ID changed from #{@incarnation_id} to #{incarnation_id}).  Reconfiguring after a randomly chosen #{splay} second delay to avoid storming the server ..."
          @incarnation_id = incarnation_id
          sleep(splay)
          client.trigger_reconfigure
        end
      end

      @online_mutex.synchronize do
        @offline_counter = 0

        if !@online && @online_counter > online_threshold
          Chef::Log.info "[#{node_name}] Server has heartbeated #{@online_counter} times without missing more than #{offline_threshold} heartbeats in a row."
          set_online(true)
        else
          @online_counter += 1
        end
      end
    end

    private

    def set_online(online)
      @online = online
      Chef::Log.info "[#{node_name}] Considering server online, and starting to heartbeat"
      @on_server_availability_change.each do |block|
        block.call(online)
      end
    end
  end
end
