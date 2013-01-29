module Smartware
  module Interface
    class Watchdog < Interface

      WATCHDOG_NOT_AVAILBLE = 1

      def initialize(config, service)
        super

        update_status :error, nil
        update_status :model, @device.model
        update_status :version, @device.version
      end

      def reboot_modem
        @device.reboot_modem

        update_status :error, @device.error
      end

      def receive_request(command, *args)
        case command
        when "reboot_modem"
          reboot_modem

        else
          super
        end
      end
    end
  end
end
