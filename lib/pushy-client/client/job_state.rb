module PushyClient
  class JobState
    attr_accessor :job_id
    attr_accessor :command
    attr_accessor :state
    attr_accessor :process

    def initialize(job_id, command, state)
      @job_id = job_id
      @command = command
      @state = state
      @process = nil
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

    def ever_started?(job_id=nil)
      (@state == :running || @state == :complete || @state == :aborted) &&
        (job_id.nil? || @job_id == job_id)
    end

    def to_s
      "#{state} #{job_id} (#{command})"
    end
  end
end
