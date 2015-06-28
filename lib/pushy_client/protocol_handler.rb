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

require 'ffi-rzmq'
require 'json'
require 'time'
require 'openssl'
require 'mixlib/authentication/digester'

class PushyClient
  class ProtocolHandler
    ##
    ## Allow send and receive times to be independently stubbed in testing. 
    ##
    class TimeSendWrapper
      def self.now
        Time.now()
      end
    end
    class TimeRecvWrapper
      def self.now
        Time.now()
      end
    end

    ZMQ_CONTEXT = ZMQ::Context.new(1)

    def initialize(client)
      @client = client
      # We synchronize on this when we change the socket (so if you want a
      # valid socket to send or receive on, synchronize on this)
      @socket_lock = Mutex.new
      # This holds the same purpose, but receive blocks for a while so it gets
      # its own lock to avoid blocking sends.  reconfigure will take both locks.
      @receive_socket_lock = Mutex.new

      # When the server goes down, close and reopen sockets.
      client.on_server_availability_change do |available|
        if !available
          Thread.new do
            begin
              Chef::Log.info "[#{node_name}] Closing and reopening sockets since server is down ..."
              reconfigure
              Chef::Log.info "[#{node_name}] Done closing and reopening sockets."
            rescue
              client.log_exception("Error reconfiguring sockets when server went down", $!)
            end
          end
        end
      end
    end

    attr_reader :client
    attr_reader :server_heartbeat_address
    attr_reader :command_address
    attr_reader :server_public_key
    attr_reader :session_key
    attr_reader :session_method
    attr_reader :client_private_key

    def node_name
      client.node_name
    end

    def start
      @server_heartbeat_address = client.config['push_jobs']['heartbeat']['out_addr']
      @command_address = client.config['push_jobs']['heartbeat']['command_addr']
      @server_public_key = OpenSSL::PKey::RSA.new(client.config['public_key'])
      @client_private_key = ProtocolHandler::load_key(client.client_key)
      @max_message_skew = client.config['max_message_skew']
      server_curve_pub_key = client.config['curve_public_key']

      # decode and extract session key
      begin 
        @session_method = client.config['encoded_session_key']['method']
        enc_session_key = Base64::decode64(client.config['encoded_session_key']['key'])
        @session_key = @client_private_key.private_decrypt(enc_session_key)
      rescue =>e
        Chef::Log.error "[#{node_name}] No session key found in config"
        exit(-1)
      end

      # Command socket
      Chef::Log.info "[#{node_name}] Connecting to command channel at #{@command_address}"
      # TODO
      # This needs to be set up to be able to handle bidirectional messages; right now this is Tx only
      # Probably need to set it up with a handler, like the subscriber socket above.
      @command_socket = ZMQ_CONTEXT.socket(ZMQ::DEALER)
      @command_socket.setsockopt(ZMQ::LINGER, 0)
      # Note setting this to '1' causes the client to crash on send, but perhaps that
      # beats storming the server when the server restarts
      @command_socket.setsockopt(ZMQ::RCVHWM, 0)
      @command_socket.setsockopt(ZMQ::CURVE_SERVERKEY, server_curve_pub_key)
      @command_socket.setsockopt(ZMQ::CURVE_PUBLICKEY, client.client_curve_pub_key)
      @command_socket.setsockopt(ZMQ::CURVE_SECRETKEY, client.client_curve_sec_key)
      @command_socket.connect(@command_address)
      @command_socket_server_seq_no = -1

      @command_socket_outgoing_seq = 0

      # Server heartbeat socket
      Chef::Log.info "[#{node_name}] Listening for server heartbeat at #{@server_heartbeat_address}"
      @server_heartbeat_socket = ZMQ_CONTEXT.socket(ZMQ::SUB)
      @server_heartbeat_socket.connect(@server_heartbeat_address)
      @server_heartbeat_socket.setsockopt(ZMQ::SUBSCRIBE, "")
      @server_heartbeat_seq_no = -1
      
      @receive_thread = start_receive_thread
    end

    def stop
      @socket_lock.synchronize do
        @receive_socket_lock.synchronize do
          internal_stop
        end
      end
    end

    def reconfigure
      @socket_lock.synchronize do
        @receive_socket_lock.synchronize do
          internal_stop
          start # Start picks up new configuration
        end
      end
    end

    def send_command(message_type, job_id)
      Chef::Log.debug("[#{node_name}] Sending command #{message_type} for job #{job_id}")
      message = {
        :node => node_name,
        :client => client.hostname,
        :org => client.org_name,
        :type => message_type,
        :sequence => -1, 
        :timestamp => TimeSendWrapper.now.httpdate,
        :incarnation_id => client.incarnation_id,
        :job_id => job_id
      }

      send_signed_json_command(:hmac_sha256, message)
    end

    def send_heartbeat(sequence)
      Chef::Log.debug("[#{node_name}] Sending heartbeat (sequence ##{sequence})")
      job_state = client.job_state
      message = {
        :node => node_name,
        :client => client.hostname,
        :org => client.org_name,
        :type => :heartbeat,
        :sequence => -1,
        :timestamp => TimeSendWrapper.now.httpdate,
        :incarnation_id => client.incarnation_id,
        :job_state => job_state[:state],
        :job_id => job_state[:job_id]
      }

      send_signed_json_command(:hmac_sha256, message)
    end

    private

    def internal_stop
      Chef::Log.info "[#{node_name}] Stopping command / server heartbeat receive thread and destroying sockets ..."
      @command_socket.close
      @command_socket = nil
      @server_heartbeat_socket.close
      @server_heartbeat_socket = nil
      @receive_thread.kill
      @receive_thread.join
      @receive_thread = nil
    end

    def start_receive_thread
      Thread.new do
        Chef::Log.info "[#{node_name}] Starting command / server heartbeat receive thread ..."
	received_command = false
	seconds_since_connection = 0
	poller = ZMQ::Poller.new
	poller.register_readable(@command_socket)
	poller.register_readable(@server_heartbeat_socket)
        while true
          begin
            messages = []
            @receive_socket_lock.synchronize do
              # Time out after 1 second to relinquish the lock and give
              # reconfigure a chance.
	      poller.poll(1000)
	      ready_sockets = poller.readables
              # Grab messages from the socket, but don't process them yet (we
              # want to relinquish the socket_lock as soon as we can)
              if ready_sockets
                ready_sockets.each do |socket|
		  header = ''
                  socket.recv_string(header)
                  if socket.more_parts?
		    message = ''
                    socket.recv_string(message)
                    if !socket.more_parts?
                      messages << [header, message]
		      if socket == @command_socket
		        received_command = true
		      end
                    else
                      # Eat up the useless packets
                      begin
			s = ''
                        socket.recv(s)
                      end while socket.more_parts?
                      Chef::Log.error "[#{node_name}] Received ZMQ message with more than two packets!  Should only have header and data packets."
                    end
                  else
                    Chef::Log.error "[#{node_name}] Received ZMQ message with only one packet!  Need both header and data packets."
                  end
                end
              end
            end

            # Need to do this to ensure reconfigure thread gets a chance to
            # wake up and grab the lock.
            sleep(0.005)

            messages.each do |message|
              if ProtocolHandler::valid?(message[0], message[1], @server_public_key, @session_key)
                handle_message(message[1])
              else
                Chef::Log.error "[#{node_name}] Received invalid message: header=#{message[0]}, message=#{message[1]}}"
              end
            end

	    if !received_command
	      seconds_since_connection += 1
	      if (seconds_since_connection > 3 )
		Chef::Log.error "[#{node_name}] No messages being received on command port.  Possible encryption problem?"
		client.trigger_reconfigure
	      end
	    end

          rescue
            client.log_exception "Error in command / server heartbeat receive thread", $!
          end
        end
      end
    end

    def handle_message(message)
      begin
        json = JSON.parse(message, :create_additions => false)

        # Verify timestamp
        if !json.has_key?('timestamp')
          Chef::Log.error "[#{node_name}] Received invalid message: missing timestamp"
          return
        end
        begin
          ts = Time.parse(json['timestamp'])
          delta = ts - TimeRecvWrapper.now
          if delta > @max_message_skew
            Chef::Log.error "[#{node_name}] Received message with timestamp too far from current time (Msg: #{json['timestamp']}, delta #{delta}, max allowed #{@max_message_skew} )"
            return 
          end
        rescue
          Chef::Log.error "[#{node_name}] Received message unparseable timestamp (Msg: #{json['timestamp']})"
          return
        end

        case json['type']
        when "heartbeat"
          incarnation_id = json['incarnation_id']
          if !incarnation_id
            Chef::Log.error "[#{node_name}] Missing incarnation_id in heartbeat message: #{message}"
          end
          sequence = json['sequence']
          if !sequence
            Chef::Log.error "[#{node_name}] Missing sequence in heartbeat message: #{message}"
          end
          client.heartbeat_received(incarnation_id, sequence)

        when "commit"
          job_id = json['job_id']
          if job_id
            command = json['command']
            if command
              client.commit(job_id, command)
            else
              Chef::Log.error "[#{node_name}] Missing command in commit message: #{message}"
              client.send_command(:nack_commit, command)
            end
          else
            Chef::Log.error "[#{node_name}] Missing job_id in commit message: #{message}"
            client.send_command(:nack_commit, job_id)
          end

        when "run"
          job_id = json['job_id']
          if job_id
            client.run(job_id)
          else
            Chef::Log.error "[#{node_name}] Missing job_id in commit message: #{message}"
            client.send_command(:nack_run, job_id)
          end

        when "abort"
          client.abort

	when "ack"
	  # Do nothing.  If this _didn't_ come through, it might mean there was
	  # an encryption problem in the command port.
	  nil

        else
          Chef::Log.error "[#{node_name}] Missing type in ZMQ message: #{message}"
        end
      rescue JSON::ParserError
        Chef::Log.error "[#{node_name}] Invalid JSON in ZMQ message: #{message}"
      end
    end

    # Message authentication (on receive)
    def self.valid?(header, message, server_public_key, session_key)
      headers = header.split(';')
      header_map = headers.inject({}) do |a,e|
        k,v = e.split(':')
        a[k] = v
        a
      end

      auth_sig  = header_map["Signature"]
      if !auth_sig
        return false
      end

      binary_sig = Base64.decode64(auth_sig)

      auth_method = header_map["SigningMethod"]
      case auth_method
      when "rsa2048_sha1"
        rsa_valid?(message, binary_sig, server_public_key)
      when "hmac_sha256"
        hmac_valid?(message, binary_sig, session_key)
      else
        false
      end
    end

    def self.rsa_valid?(message, sig, server_public_key)
      decrypted_checksum = server_public_key.public_decrypt(sig)
      hashed_message = Mixlib::Authentication::Digester.hash_string(message)
      decrypted_checksum == hashed_message
    end

    def self.hmac_valid?(message, sig, session_key)
      message_sig = OpenSSL::HMAC.digest('sha256', session_key, message)
      # Defeat timing attacks; attacking this requires breaking SHA.
      sha = OpenSSL::Digest::SHA512.new
      sha.digest(sig) == sha.digest(message_sig)
    end

    # Message signing and sending (on send)
    def send_signed_json_command(method, json)
      @socket_lock.synchronize do
        @command_socket_outgoing_seq += 1
        json[:sequence] = @command_socket_outgoing_seq
        message = JSON.generate(json)
        if @command_socket
          ProtocolHandler::send_signed_message(@command_socket, method, @client_private_key, @session_key, message)
        else
          Chef::Log.warn("[#{node_name}] Dropping packet because client was stopped: #{message}")
        end
      end
    end

    def self.send_signed_message(socket, method, client_private_key, session_key, message)
      auth = case method
             when :rsa2048_sha1
               make_header_rsa(message, client_private_key)
             when :hmac_sha256
               make_header_hmac(message, session_key)
             end
      socket.send_string(auth, ZMQ::SNDMORE)
      socket.send_string(message)
    end

    def self.load_key(key_path)
      raw_key = IO.read(key_path).strip
      OpenSSL::PKey::RSA.new(raw_key)
    end

    def self.make_header_rsa(json, client_private_key)
      checksum = Mixlib::Authentication::Digester.hash_string(json)
      b64_sig = Base64.encode64(client_private_key.private_encrypt(checksum)).chomp
      "Version:2.0;SigningMethod:rsa2048_sha1;Signature:#{b64_sig}"
    end

    def self.make_header_hmac(json, session_key)
      sig = OpenSSL::HMAC.digest('sha256', session_key, json)
      b64_sig = Base64.encode64(sig).chomp
      "Version:2.0;SigningMethod:hmac_sha256;Signature:#{b64_sig}"
    end
  end
end
