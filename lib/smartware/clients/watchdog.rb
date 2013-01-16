require 'drb'

module Smartware
  module Client

    module Watchdog

      DRb.start_service
      @device = DRbObject.new_with_uri('druby://localhost:6003')

      def self.error
        @device.error
      rescue => e
        'No device'
      end

      def self.model
        @device.model
      rescue => e
        'No device'
      end

      def self.version
        @device.version
      rescue => e
        'No device'
      end

      def self.reboot_modem
        @device.reboot_modem
      rescue => e
        'No device'
      end
    end
  end
end
