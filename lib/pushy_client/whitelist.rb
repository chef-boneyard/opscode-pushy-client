class PushyClient
  class Whitelist < Hash

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
                return argument.gsub(key, value[:command_line])
              else
                return argument.gsub(key, value)
              end
            end
          end
        end
      end

      nil
    end
  end
end

