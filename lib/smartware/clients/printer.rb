require 'drb'

module Smartware
  module Client

    module Printer

      DRb.start_service
      @device = DRbObject.new_with_uri('druby://localhost:6005')

      #def self.configure(port, driver)
      #  DRb.start_service
      #  @device = DRbObject.new_with_uri('druby://localhost:6005')
      #  @device.configure!(port, driver)
      #end

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

      def self.test
        @device.test
      rescue => e
        'No device'
      end

      def self.print(filepath)
        @device.print filepath
      rescue => e
        'No device'
      end

    end
  end
end
