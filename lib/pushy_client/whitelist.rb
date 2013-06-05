class PushyClient
  class Whitelist

    attr_accessor :whitelist

    def initialize(whitelist)
      @whitelist = whitelist
    end

    def [](argument)
      # If we have an exact match, use it
      if whitelist.has_key?(argument)
        return whitelist[argument]
      else
        whitelist.keys.each do |key|
          if key.kind_of?(Regexp)
            if key.match(argument)
              value = whitelist[key]
              if value.kind_of?(Hash)
                # Need a deep copy, don't want to change the global value
                new_value = Marshal.load(Marshal.dump(value))
                new_value[:command_line] = argument.gsub(key, value[:command_line])
                return new_value
              else
                return argument.gsub(key, value)
              end
            end
          end
        end
      end

      nil
    end

    def method_missing(method, *args, &block)
      @whitelist.send(method, *args, &block)
    end
  end
end

