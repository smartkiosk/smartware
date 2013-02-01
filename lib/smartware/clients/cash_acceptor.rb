require 'drb'

module Smartware
  module Client

    module CashAcceptor

      DRb.start_service
      @device = DRbObject.new_with_uri('druby://localhost:6001')

      def self.open(limit_min = nil, limit_max = nil)
        @device.open_session(limit_min, limit_max)
      end

      def self.close
        @device.close_session
      end

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

      def self.banknotes
        @device.banknotes
      end

      def self.sum
        @device.cashsum
      end

      def self.insert_casette
        @device.insert_casette
      end

      def self.eject_casette
        @device.eject_casette
      end
    end
  end
end
