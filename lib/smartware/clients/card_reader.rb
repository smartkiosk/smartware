require 'drb'

module Smartware
  module Client

    module CardReader

      DRb.start_service
      @device = DRbObject.new_with_uri('druby://localhost:6004')

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

      def self.card_inserted?
        @device.card_inserted?
      end

      def self.present?
        @device.present?
      end

      def self.start_accepting
        @device.start_accepting
      end

      def self.stop_accepting
        @device.stop_accepting
      end

      def self.eject
        @device.eject
      end

      def self.capture
        @device.capture
      end

      def self.read_magstrip
        @device.read_magstrip
      end
    end
  end
end
