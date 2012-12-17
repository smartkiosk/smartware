require 'drb'
require 'smartware/drivers/modem/standart'
require 'smartware/drivers/modem/dummy'

module Smartware
  module Interface

    module Modem

      @configured = false
      @status = {}

      def self.configure!(port, driver)
        @device = Smartware::Driver::Modem.const_get(driver).new(port)
        @session.kill if @session
        @session = self.poll_status!
        @configured = true
        @status = {}
      rescue => e
        Smartware::Logging.logger.error e.message
        Smartware::Logging.logger.error e.backtrace.join("\n")
        @configured = false
      end

      def self.configured?
        @configured
      end

      def self.error
        @status[:error] || ''
      end

      def self.model
        @status[:model]
      end

      def self.balance
        @status[:balance]
      end

      def self.signal_level
        @status[:signal_level]
      end

      def self.d_model
        @device.model
      end

      def self.d_signal
        @device.signal_level
      end

      def self.d_balance
        @device.ussd
      end

      def self.d_stop
        @session.kill
      end

      private
        def self.poll_status!
          t = Thread.new do
            loop do
              @status[:signal_level] = @device.signal_level
              @status[:model]   = @device.model
              @status[:error]   = @device.error
              @status[:balance] = @device.ussd('*100#')
              sleep 30
            end
          end
        end
    end

  end
end

DRb.start_service('druby://localhost:6002', Smartware::Interface::Modem)
DRb.thread.join

