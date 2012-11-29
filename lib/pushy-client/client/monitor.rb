module PushyClient
  class Monitor
    def initialize(options)
      @on_threshold = options[:online_threshold]
      @off_threshold = options[:offline_threshold]
      @interval = options[:interval]
      @on_counter = @off_counter = 0
      @online = true
      @callbacks = {}
      @server_incarnation_id = nil
    end

    def callback(type, &block)
      @callbacks[type.to_sym] ||= []
      @callbacks[type.to_sym] << block
    end

    def checkin!(data)
      # check to see if the incarnation has changed; that indicates a server restart.
      incarnation_id = data["incarnation_id"]
      if (@server_incarnation_id == nil)
        @server_incarnation_id = data["incarnation_id"]
      elsif (@server_incarnation_id !=  data["incarnation_id"])
        # server has changed id; trigger reconnect
        Chef::Log.error "Server Restart id was #{@server_incarnation_id} now #{data['incarnation_id']}"
        @server_incarnation_id = data["incarnation_id"]
        fire_callback(:server_restart)
      end

      @off_counter = 0

      if @on_counter > @on_threshold
        set_online(true)
      else
        @on_counter += 1
      end
    end

    def online?
      @online
    end

    def set_online(online)
      if online
        if !@online
          @online = true
          fire_callback(:after_online)
        end
      elsif @online
        @online = false
      end
    end

    def start
      @timer = EM::PeriodicTimer.new(@interval) do
        if @off_counter > @off_threshold
          reset!
          set_online(false)
        else
          @off_counter += 1
        end
      end
    end

    def stop
      @timer.cancel
    end

    def reset!
      @on_counter = @off_counter = 0
    end

    private

    def fire_callback(type)
      if callables = @callbacks[type.to_sym]
        callables.each { |callable| callable.call }
      else
        Chef::Log.error "Can't fire_callback for '#{type}'"
      end
    end

  end
end
