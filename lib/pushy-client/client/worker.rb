require 'time'
require 'pp'
require 'pushy-client/client/job_state'

module PushyClient
  class Worker
    attr_reader :app, :monitor, :timer, :job

    attr_accessor :ctx
    attr_accessor :out_address
    attr_accessor :cmd_address
    attr_accessor :interval
    attr_accessor :offline_threshold
    attr_accessor :online_threshold
    attr_accessor :lifetime
    attr_accessor :client_private_key
    attr_accessor :server_public_key
    attr_accessor :session_key
    attr_accessor :session_method
    attr_accessor :subscriber
    attr_accessor :cmd_socket
    attr_accessor :on_state_change

    def initialize(_app, options)
      @app = _app
      @job = JobState.new(nil, nil, :idle)

      @monitor = PushyClient::Monitor.new(options)
      @ctx = EM::ZeroMQ::Context.new(1)
      @out_address = options[:out_address]
      @cmd_address = options[:cmd_address]
      @interval = options[:interval]
      @client_key_path = options[:client_key]
      @server_key_path = options[:server_key]

      @offline_threshold = options[:offline_threshold]
      @online_threshold = options[:online_threshold]
      @lifetime = options[:lifetime]

      @client_private_key = load_key(app.client_private_key_path)
      @server_public_key = OpenSSL::PKey::RSA.new(options[:server_public_key]) || load_key(options[:server_public_key_path])
      # TODO: this key should be encrypted!
      @session_method = options[:session_method]
      @session_key    = Base64::decode64(options[:session_key])
      @sequence = 0

      # TODO: This should be preserved across clean restarts...
      @incarnation_id = UUIDTools::UUID.random_create
    end

    def change_job(job)
      PushyClient::Log.info("[#{node_name}] Changing to new job: #{job}")
      @job = job
      on_state_change.call(self.job) if on_state_change
    end

    def clear_job
      PushyClient::Log.info("[#{node_name}] Clearing current job: #{job}")
      @job = JobState.new(nil, nil, :idle)
      on_state_change.call(self.job) if on_state_change
    end

    def send_command(message_type, job_id)
      PushyClient::Log.info("[#{node_name}] Sending command #{message_type} to job #{job_id}")
      message = {
        :node => node_name,
        :client => (`hostname`).chomp,
        :org => org_name,
        :type => message_type,
        :timestamp => Time.now.httpdate,
        :incarnation_id => @incarnation_id,
        :job_id => job_id
      }

      send_signed_json(self.cmd_socket, :hmac_sha256, message)
    end

    def send_heartbeat
      PushyClient::Log.info("[#{node_name}] Sending heartbeat")
      message = {
        :node => node_name,
        :client => (`hostname`).chomp,
        :org => org_name,
        :type => :heartbeat,
        :timestamp => Time.now.httpdate,
        :incarnation_id => @incarnation_id,
        :job_state => job.state,
        :job_id => job.job_id,
        :sequence => @sequence
      }

      @sequence+=1

      send_signed_json(self.cmd_socket, :hmac_sha256, message)
    end

    def node_name
      app.node_name
    end

    def org_name
      app.org_name
    end

    class << self
      def load!(app)
        from_hash(app, get_config_json(app))
      end

      def from_json(app, raw_json_config)
        from_hash(Yajl::Parser.parse(raw_json_config))
      end

      def from_hash(app, config)
        new app,
          :out_address       => config['push_jobs']['heartbeat']['out_addr'],
          :cmd_address       => config['push_jobs']['heartbeat']['command_addr'],
          :interval          => config['push_jobs']['heartbeat']['interval'],
          :offline_threshold => config['push_jobs']['heartbeat']['offline_threshold'],
          :online_threshold  => config['push_jobs']['heartbeat']['online_threshold'],
          :lifetime          => config['lifetime'],
          :server_public_key => config['public_key'],
          :session_key       => config['session_key']['key'],
          :session_method    => config['session_key']['method']
      end


      def get_config_json(app)
        node_name = app.node_name
        PushyClient::Log.info "[#{node_name}] Worker: Fetching configuration ..."
        app.get_rest("pushy/config/#{node_name}", false)
      end
    end

    def start

      # TODO: Define hwm behavior for sockets below

      # Subscribe to heartbeat from the server
      PushyClient::Log.info "[#{node_name}] Worker: Listening for server heartbeat at #{out_address}"
      self.subscriber = ctx.socket(ZMQ::SUB, PushyClient::Handler::Heartbeat.new(monitor, self))
      self.subscriber.connect(out_address)
      self.subscriber.setsockopt(ZMQ::SUBSCRIBE, "")

      # command socket for server
      PushyClient::Log.info "[#{node_name}] Worker: Connecting to command channel at #{cmd_address}"
      # TODO
      # This needs to be set up to be able to handle bidirectional messages; right now this is Tx only
      # Probably need to set it up with a handler, like the subscriber socket above.
      self.cmd_socket = ctx.socket(ZMQ::DEALER, PushyClient::Handler::Command.new(self))
      self.cmd_socket.setsockopt(ZMQ::LINGER, 0)
      # Note setting this to '1' causes the client to crash on send, but perhaps that
      # beats storming the server when the server restarts
      self.cmd_socket.setsockopt(ZMQ::HWM, 0)
      self.cmd_socket.connect(cmd_address)

      monitor.callback(:server_restart) do
        app.reload
      end

      monitor.start

      send_heartbeat

      # Set up the client->server heartbeat on a timer
      PushyClient::Log.debug "[#{node_name}] Worker: Setting heartbeat at every #{interval} seconds"
      @timer = EM::PeriodicTimer.new(interval) do
        send_heartbeat
      end
    end

    def stop
      PushyClient::Log.debug "[#{node_name}] Worker: Stopping ..."
      monitor.stop
      timer.cancel
      job.cancel
      PushyClient::Log.debug "[#{node_name}] Worker: Stopped."
    end

    private

    def load_key(key_path)
      raw_key = IO.read(key_path).strip
      OpenSSL::PKey::RSA.new(raw_key)
    end

    def make_header_rsa(json)
      checksum = Mixlib::Authentication::Digester.hash_string(json)
      b64_sig = Base64.encode64(client_private_key.private_encrypt(checksum)).chomp
      "Version:2.0;SigningMethod:rsa2048_sha1;Signature:#{b64_sig}"
    end
    def make_header_hmac(json)
      sig = OpenSSL::HMAC.digest('sha256', session_key, json)
      b64_sig = Base64.encode64(sig).chomp
      "Version:2.0;SigningMethod:hmac_sha256;Signature:#{b64_sig}"
    end

    def send_signed_json(socket, method, message)
      json = Yajl::Encoder.encode(message)
      auth = case method
             when :rsa2048_sha1
               make_header_rsa(json)
             when :hmac_sha256
               make_header_hmac(json)
             end

#      PushyClient::Log.debug "[#{node_name}] Sending Message #{method} #{auth} #{json}"

      socket.send_msg(auth, json)
    end

  end
end
