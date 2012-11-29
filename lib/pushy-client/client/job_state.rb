module PushyClient
  class JobState
    attr_accessor :job_id
    attr_accessor :command
    attr_accessor :state
    attr_accessor :pid

    def initialize(job_id, command, state)
      @job_id = job_id
      @command = command
      @state = state
      @pid = nil
    end

    def idle?
      job_id == nil || (state != :ready && state != :running)
    end

    def ready?(job_id=nil)
      @state == :ready && (job_id.nil? || @job_id == job_id)
    end

    def running?(job_id=nil)
      @state == :running && (job_id.nil? || @job_id == job_id)
    end

    def to_s
      "#{state} #{job_id} (#{command})"
    end

    def cancel
      if pid
        Process.kill(1, pid)
        pid = nil
      end
    end
  end
end
