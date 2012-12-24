require 'drb'

module Smartware
  module Client

    module Modem

      DRb.start_service
      @device = DRbObject.new_with_uri('druby://localhost:6002')

      def self.error
        @device.error
      end

      def self.model
        @device.model
      end

      def self.balance
        @device.balance
      end

      def self.signal_level
        @device.signal_level
      end

    end
  end
end
