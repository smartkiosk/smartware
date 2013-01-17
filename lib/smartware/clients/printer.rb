require 'drb'

module Smartware
  module Client

    module Printer

      DRb.start_service
      @device = DRbObject.new_with_uri('druby://localhost:6005')

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

      def self.test
        @device.test
      rescue => e
        'No device'
      end

      def self.print(text, max_time = 30)
        @device.print text, max_time
      rescue => e
        'No device'
      end

      def self.print_text(text, max_time = 30)
        @device.print_text text, max_time
      rescue => e
        'No device'
      end

      def self.print_markdown(text, max_time = 30)
        @device.print_markdown text, max_time
      rescue => e
        'No device'
      end

    end
  end
end
