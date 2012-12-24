require 'drb'
require 'smartware/drivers/modem/standard'
require 'smartware/drivers/modem/dummy'

module Smartware
  module Interface

    module Modem

      @configured = false
      @status = {}

      def self.configure!(port=nil, driver=nil)
        @device = Smartware::Driver::Modem.const_get(
            Smartware::Service.config['modem_driver']).new(
            Smartware::Service.config['modem_port'])
        @session.kill if @session
        @session = self.poll_status!
        @configured = true
        Smartware::Logging.logger.info 'Modem monitor started'
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

      self.configure!
    end
  end
end

DRb.start_service('druby://localhost:6002', Smartware::Interface::Modem)
DRb.thread.join

