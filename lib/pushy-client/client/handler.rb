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

      attr_reader :worker

      def initialize(worker)
        @worker = worker
      end

      def on_readable(socket, parts)
        return unless valid?(parts)
        command_hash = Utils.parse_json(parts[1].copy_out_string)

        PushyClient::Log.debug "Received command #{command_hash}"
        if command_hash['type'] == "commit"
          ack_nack(command_hash['job_id'], command_hash['command'])
        elsif command_hash['type'] == "run"
          run_command(command_hash['job_id'], command_hash['command'])
        elsif command_hash['type'] == "abort"
          abort
        else
          PushyClient::Log.error "Received unknown command #{command_hash}"
        end

      end

      private

      def ack_nack(job_id, command)
        # If we are ready or have started this job, do nothing.
        if worker.job.ready?(job_id) || worker.job.running?(job_id)
          PushyClient::Log.warn "Received command request for job #{job_id} after twice: doing nothing."
          worker.send_command(:ack_commit, job_id)

        # If we are idle, ack.
        elsif worker.job.idle?
          worker.send_command(:ack_commit, job_id)
          worker.change_job(JobState.new(job_id, command, :ready))

        # Otherwise, we're involved with some other job.  ack.
        else
          worker.send_command(:nack_commit, job_id)
          worker.clear_job
        end
      end

      def run_command(job_id, command)
        # If we are already running this job, do nothing.
        if worker.job.running?(job_id)
          PushyClient::Log.warn "Received execute request for job #{job_id} twice: doing nothing."

        # If we are ready for this job, or are idle, start.
        elsif worker.job.ready?(job_id) || worker.job.idle?
          worker.send_command(:ack_run, job_id)
          worker.change_job(JobState.new(job_id, command, :running))

          worker.job.process = EM::DeferrableChildProcess.open(command)
          # TODO what if this fails?
          worker.job.process.callback do |data_from_child|
            worker.send_command(:complete, job_id)
            worker.clear_job
          end

        # Otherwise, we're clearly working on another job.  Ignore this request.
        # TODO perhaps remind the server of our state with respect to this job.
        else
          worker.send_command(:nack_run, job_id)
          PushyClient::Log.warn "Received execute request for job #{job_id} when we are already #{worker.job}: Doing nothing."
        end
      end

      def abort
        worker.job.process.cancel if worker.job.running?
        worker.send_command(:aborted, worker.job.job_id)
        worker.clear_job
      end

      def valid?(parts)
        Utils.valid?(parts, worker.server_public_key)
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

