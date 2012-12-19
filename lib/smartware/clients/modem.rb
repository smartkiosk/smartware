require 'drb'

module Smartware
  module Client

    module Modem

      DRb.start_service
      @device = DRbObject.new_with_uri('druby://localhost:6002')

      #def self.configure(port, driver)
      #  DRb.start_service
      #  @device = DRbObject.new_with_uri('druby://localhost:6002')
      #  @device.configure!(port, driver)
      #end

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

      def self.d_model
        @device.d_model
      end

      def self.d_signal
        @device.d_signal
      end

      def self.d_balance
        @device.d_balance
      end

      def self.d_stop
        @device.d_stop
      end



    end
  end
end
