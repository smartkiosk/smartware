require 'drb'

module Smartware
  module Client

    module Watchdog

      DRb.start_service
      @device = DRbObject.new_with_uri('druby://localhost:6003')

      def self.error
        @device.error
      end

      def self.model
        @device.model
      end

      def self.version
        @device.version
      end

      def self.reboot_modem
        @device.reboot_modem
      end
    end
  end
end
