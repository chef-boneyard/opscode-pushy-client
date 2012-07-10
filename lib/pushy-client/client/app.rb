require 'time'
require 'pp'

module PushyClient
  class App
    DEFAULT_SERVICE_URL_BASE = "localhost:10003/organization/clownco"

    attr_accessor :service_url_base
    attr_accessor :client_private_key_path
    attr_accessor :node_name

    attr_accessor :reaper, :worker


    def initialize(options)
      @service_url_base        = options[:service_url_base]
      @client_private_key_path = options[:client_private_key_path]
      @node_name               = options[:node_name]

      PushyClient::Log.info "Using configuration endpoint: #{service_url_base}"
      PushyClient::Log.info "Using private key: #{client_private_key_path}"
      PushyClient::Log.info "Using node name: #{node_name}"
    end

    def start
      PushyClient::Log.info "Booting ..."

      EM.run do
        start_worker
      end

    end

    def stop
      PushyClient::Log.info "Stopping client ..."
      worker.stop
      PushyClient::Log.info "Stopped."
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
