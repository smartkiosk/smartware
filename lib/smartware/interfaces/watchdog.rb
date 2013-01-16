module Smartware
  module Interface
    class Watchdog < Interface

      WATCHDOG_NOT_AVAILBLE = 1

      def initialize(config)
        super

        update_status do
          @status[:error] = nil
          @status[:model] = @device.model
          @status[:version] = @device.version
        end
      end

      def reboot_modem
        @device.reboot_modem

        update_status do
          @status[:error] = @device.error
        end
      end
    end
  end
end
