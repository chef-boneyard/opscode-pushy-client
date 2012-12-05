class PushyClient
  class PeriodicReconfigurer
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
      @reconfigure_thread = Thread.new do
        Chef::Log.info "[#{node_name}] Starting reconfigure thread.  Will reconfigure / reload keys after #{@lifetime} seconds."
        while true
          begin
            sleep(@lifetime)
            Chef::Log.info "[#{node_name}] Config is now #{@lifetime} seconds old.  Reconfiguring / reloading keys ..."
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
