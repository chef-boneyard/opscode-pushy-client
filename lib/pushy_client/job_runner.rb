class PushyClient
  class JobRunner
    def initialize(client)
      @client = client
      @state = :idle
      @job_id = nil
      @command = nil
      @pid = nil
      @process_thread = nil

      # Keep job state and process state in sync
      @state_lock = Mutex.new
    end

    attr_reader :client
    attr_reader :state
    attr_reader :job_id
    attr_reader :command

    def node_name
      client.node_name
    end

    def start
    end

    def stop
      if @state == :running
        kill_process
      end
      @state = :idle
      @job_id = nil
      @command = nil
    end

    def reconfigure
      # We have no configuration, and keep state between reconfigures
    end

    def commit(job_id, command)
      @state_lock.synchronize do
        if @state == :idle
          Chef::Log.info("[#{node_name}] Received commit #{job_id}")
          @state = :committed
          @job_id = job_id
          @command = command
          client.send_command(:ack_commit, job_id)
          true
        else
          Chef::Log.info("[#{node_name}] Received commit #{job_id} but current state is #{@state} #{@job_id}")
          client.send_command(:nack_commit, job_id)
          false
        end
      end
    end

    def run(job_id)
      @state_lock.synchronize do
        if @state == :committed && @job_id == job_id
          Chef::Log.info("[#{node_name}] Received run #{job_id}")
          @state = :running
          start_process
          client.send_command(:ack_run, job_id)
          true
        else
          Chef::Log.warn("[#{node_name}] Received run #{job_id} but current state is #{@state} #{@job_id}")
          client.send_command(:nack_run, job_id)
          false
        end
      end
    end

    def abort
      Chef::Log.info("[#{node_name}] Received abort")
      @state_lock.synchronize do
        stop
        client.send_command(:aborted, job_id)
      end
    end

    def job_state
      @state_lock.synchronize do
        {
          :state => @state,
          :job_id => @job_id,
          :command => @command
        }
      end
    end

    private

    def completed(job_id, exit_code)
      Chef::Log.info("[#{node_name}] Job #{job_id} completed with exit code #{exit_code}")
      @state_lock.synchronize do
        if @state == :running && @job_id == job_id
          @state = :idle
          @job_id = nil
          @command = nil
          @pid = nil
          @process_thread = nil
          status = exit_code == 0 ? :succeeded : :failed
          client.send_command(status, job_id)
        end
      end
    end

    def start_process
      # _pid and _job_id are local variables so that if @pid or @job_id change
      # for any reason (for example, they become nil), the thread we create
      # still tracks the correct pid.
      @pid = _pid = Process.spawn({'PUSHY_NODE_NAME' => node_name}, command)
      _job_id = @job_id
      Chef::Log.info("[#{node_name}] Job #{job_id}: started command '#{command}' with PID '#{_pid}'")

      # Wait for the job to complete and close it out.
      @process_thread = Thread.new do
        begin
          pid, exit_code = Process.waitpid2(_pid)
          completed(_job_id, exit_code)
        rescue
          client.log_exception("Exception raised while waiting for job #{_job_id} to complete", $!)
          abort
        end
      end
    end

    def kill_process
      Chef::Log.info("[#{node_name}] Killing process #{@pid}")
      @process_thread.kill
      @process_thread.join
      Process.kill(1, @pid)
      @pid = nil
      @process_thread = nil
    end
  end
end
