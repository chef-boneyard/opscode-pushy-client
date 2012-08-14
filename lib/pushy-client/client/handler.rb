require 'eventmachine'

module PushyClient
  module Handler
    class Heartbeat

      attr_reader :received
      attr_accessor :monitor

      def initialize(monitor, client)
        @monitor = monitor
        @client = client
      end

      def on_readable(socket, parts)
        if valid?(parts)
          data = Utils.parse_json(parts[1].copy_out_string)
          monitor.checkin!(data)
        end

      end

      private

      def valid?(parts)
        Utils.valid?(parts, @client.server_public_key)
      end

    end

    class Command

      def initialize(worker)
        @worker = worker
      end

      def on_readable(socket, parts)
        return unless valid?(parts)
        command_hash = Utils.parse_json(parts[1].copy_out_string)

        PushyClient::Log.debug "Received command #{command_hash}"
        if command_hash['type'] == "job_command"
          ack_nack(command_hash)
        elsif command_hash['type'] == "job_execute"
          run_command(command_hash)
        end

      end

      private

      def ack_nack(command_hash)
        # If we are idle, or if we are already ready or executing THIS job,
        # ack.  Otherwise, nack.  TODO: is :ack really appropriate for executing?
        if @worker.state == "idle" ||
           @worker.command_hash['job_id'] == command_hash['job_id']
          # TODO there is a race condition here where we could acknowledge two
          # different jobs if two jobs ask for us at the same time.
          @worker.change_state "ready"
          @worker.send_command_message(:ack, command_hash['job_id'])
          @worker.command_hash = command_hash
        else
          @worker.send_command_message(:nack, command_hash['job_id'])
        end
      end

      def run_command(command_hash)
        # If we are already running this job, do nothing.  TODO should we send
        # a started message?  Clearly someone didn't get the memo ...
        if @worker.state == "running" && @worker.command_hash['job_id'] == command_hash['job_id']
          PushyClient::Log.info "Received execute request for job #{command_hash['job_id']} twice: doing nothing."

        # If we are idle, or ready to do this job, run the job and say "started."
        elsif @worker.state == "idle" || @worker.command_hash['job_id'] == command_hash['job_id']
          PushyClient::Log.info "Starting job #{command_hash['job_id']}: #{command_hash['command']}."
          # TODO there is a race condition here where we could run the job twice
          # if we get two execute messages close to each other.  This could actually
          # happen if we had a server restart and network congestion at the right time.
          # TODO we might should check whether the "ready" command is the same as the "execute" command
          @worker.command_hash = command_hash # In case we were idle, this needs to be set
          @worker.change_state "running"
          @worker.send_command_message(:started, command_hash['job_id'])
          command = EM::DeferrableChildProcess.open(command_hash['command'])
          # TODO what if this fails?
          command.callback do |data_from_child|
            # TODO there is a race here: if the heartbeat monitor fires between
            # the next two statements, we will send heartbeat "idle" before the
            # "finished" message, which is a confused thing to do.
            @worker.change_state "idle"
            @worker.command_hash = nil
            @worker.send_command_message(:finished, command_hash['job_id'])
          end
        else
          # Otherwise, respond with a nack.  TODO: do we need a new message for this,
          # or is nack sufficient?
          @worker.send_command_message(:nack, command_hash['job_id'])
        end
      end

      def valid?(parts)
        Utils.valid?(parts, @worker.server_public_key)
      end

    end

    module Utils

      def self.valid?(parts, server_public_key)
        auth = parts[0].copy_out_string.split(':')[2]
        body = parts[1].copy_out_string

        decrypted_checksum = server_public_key.public_decrypt(Base64.decode64(auth))
        hashed_body = Mixlib::Authentication::Digester.hash_string(body)

        decrypted_checksum == hashed_body
      end

      def self.parse_json(json)
        Yajl::Parser.new.parse(json).tap do |body_hash|
          #ap body_hash
        end
      end

    end
  end
end

