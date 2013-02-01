require 'drb'

module Smartware
  module Client

    module CardReader

      DRb.start_service
      @device = DRbObject.new_with_uri('druby://localhost:6004')


      def self.status
        @device.status
      end

      def self.error
        @device.error
      end

      def self.model
        @device.model
      end

      def self.version
        @device.version
      end

      def self.open
        @device.open
      end

      def self.close
        @device.close
      end

      def self.card_inserted
        @device.card_inserted
      end
    end
  end
end
