class PushyClient
  class Heartbeater
    def initialize(client)
      @client = client
      @online_mutex = Mutex.new
      @heartbeat_sequence = 1
      @on_server_availability_change = []
    end

    attr_reader :client
    attr_reader :incarnation_id
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
      @interval = client.config['push_jobs']['heartbeat']['interval']

      set_online(true)

      @heartbeat_thread = Thread.new do
        Chef::Log.info "[#{node_name}] Starting heartbeat / offline detection thread on interval #{interval} ..."

        while true
          begin
            # When the server goes more than <offline_threshold> intervals
            # without sending us a heartbeat, treat it as offline

            # We only send heartbeats to online servers
            if @online
              client.send_heartbeat(@heartbeat_sequence)
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

    private

    def set_online(online)
      @online = online
      @on_server_availability_change.each do |block|
        block.call(online)
      end
    end
  end
end
