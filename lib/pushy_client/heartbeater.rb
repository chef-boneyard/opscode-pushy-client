class PushyClient
  class Heartbeater
    def initialize(client)
      @client = client
      @online_mutex = Mutex.new
      @heartbeat_sequence = 1
    end

    attr_reader :client
    attr_reader :incarnation_id
    attr_reader :online_threshold
    attr_reader :offline_threshold
    attr_reader :interval

    def node_name
      client.node_name
    end

    def start
      @incarnation_id = nil
      @online_threshold = client.config['push_jobs']['heartbeat']['online_threshold']
      @offline_threshold = client.config['push_jobs']['heartbeat']['offline_threshold']
      @interval = client.config['push_jobs']['heartbeat']['interval']

      @online_counter = 0
      @offline_counter = 0
      @online = false

      @heartbeat_thread = Thread.new do
        Chef::Log.info "[#{node_name}] Starting heartbeat / offline detection thread ..."
        while true
          begin
            # When the server goes more than <offline_threshold> intervals
            # without sending us a heartbeat, treat it as offline
            @online_mutex.synchronize do
              if @online
                if @offline_counter > offline_threshold
                  Chef::Log.info "[#{node_name}] Server has missed #{@offline_counter} heartbeats in a row.  Considering it offline, and stopping heartbeat."
                  @online = false
                else
                  @offline_counter += 1
                end
              end
            end

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
      heartbeat_thread = @heartbeat_thread
      if heartbeat_thread
        heartbeat_thread.kill
        heartbeat_thread.join
      end
    end

    def reconfigure
      stop
      start # Start picks up new configuration
    end

    # TODO use the sequence for something?
    def heartbeat_received(incarnation_id, sequence)
      Chef::Log.debug("[#{node_name}] Received server heartbeat (sequence ##{sequence})")
      # If the incarnation id has changed, we need to reconfigure.
      if @incarnation_id != incarnation_id
        if @incarnation_id.nil?
          Chef::Log.info "[#{node_name}] First heartbeat received.  Server is at incarnation ID #{incarnation_id}."
        else
          Chef::Log.info "[#{node_name}] Server restart detected (incarnation ID changed from #{@incarnation_id} to #{incarnation_id}).  Reconfiguring ..."
          client.reconfigure
        end
        @incarnation_id = incarnation_id
      end

      @online_mutex.synchronize do
        @offline_counter = 0

        if !@online && @online_counter > online_threshold
          Chef::Log.info "[#{node_name}] Server has heartbeated #{@online_counter} times without missing more than #{offline_threshold} heartbeats in a row.  Considering it online, and starting to heartbeat ..."
          @online = true
        else
          @online_counter += 1
        end
      end
    end
  end
end
