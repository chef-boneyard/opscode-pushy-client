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
        if command_hash['type'] == "job_command"
          ack_nack(command_hash['job_id'], command_hash['command'])
        elsif command_hash['type'] == "job_execute"
          run_command(command_hash['job_id'], command_hash['command'])
        elsif command_hash['type'] == "job_release"
          release(command_hash['job_id'])
        elsif command_hash['type'] == "job_abort"
          abort(command_hash['job_id'])
        else
          PushyClient::Log.error "Received unknown command #{command_hash}"
        end

      end

      private

      def ack_nack(job_id, command)
        # If we are idle, or if we are already ready for THIS job,
        # ack.  Otherwise, nack.  TODO: is :ack really appropriate for executing?
        if worker.job.idle?
          worker.change_job(JobState.new(job_id, command, :ready))

        # Already running.  Nothing to do.
        elsif worker.job.running?(job_id)
          PushyClient::Log.warn "Received command request for job #{job_id} after twice: doing nothing."

        elsif
          nacked_job = JobState.new(job_id, command, :never_run)
          worker.send_state_message(:state_change, nacked_job)
        end
      end

      def run_command(job_id, command)
        # If we are idle, or ready to do this job, run the job and say "started."
        if worker.job.idle? || worker.job.ready?(job_id)
          worker.change_job(JobState.new(job_id, command, :running))

          worker.job.process = EM::DeferrableChildProcess.open(command)
          # TODO what if this fails?
          worker.job.process.callback do |data_from_child|
            worker.change_job_state(:complete)
          end

        # If we are already running this job, do nothing.  TODO should we send
        # a started message?  Clearly someone didn't get the memo ...
        elsif worker.job.running?(job_id)
          PushyClient::Log.warn "Received execute request for job #{job_id} twice: doing nothing."

        else
          PushyClient::Log.warn "Received execute request for job #{job_id} when we are already #{worker.job}: Doing nothing."
        end
      end

      def release(job_id)
        # Only abort if the abort command is for the job WE are running.
        if worker.job.ready?(job_id)
          PushyClient::Log.info "Releasing job #{worker.job}"
          worker.change_job_state(:new)
        else
          PushyClient::Log.warn "Received release request for job #{job_id}, but currently #{worker.job}."
        end
      end

      def abort(job_id)
        # Only abort if the abort command is for the job WE are running.
        if worker.job.running?(job_id)
          worker.job.process.cancel
          worker.change_job_state(:aborted)
        else
          PushyClient::Log.warn "Received abort request for job #{job_id}, but currently #{worker.job}."
        end
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

