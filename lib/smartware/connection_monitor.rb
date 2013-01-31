module Smartware
  class ConnectionMonitor
    def initialize(timeout)
      @timeout = [ timeout / 5, 1 ].max
      @counter = @timeout
    end

    def run
      loop do
        if Smartware.modem.error.nil?
          @counter = @timeout
        else
          if @counter == 0
            Smartware.watchdog.reboot_modem
            @counter = @timeout
          else
            @counter -= 1
          end
        end

        sleep 5
      end
    end
  end
end
