require 'drb'
require 'smartware/drivers/printer/dummy'
require 'smartware/drivers/printer/tg24xx'

module Smartware
  module Interface

    module Printer

      @configured = false
      @status = {:error => ''}
      @queue = []

      def self.configure!(port, driver)
        @device = Smartware::Driver::Printer.const_get(driver).new(port)
        @session.kill if @session and @session.alive?
        @session = self.start_monitor!
        Smartware::Logging.logger.info 'Printer monitor started'
        @configured = true
      rescue => e
        @configured = false
      end

      def self.configured?
        @configured
      end

      def self.error
        @status[:error]
      end

      def self.model
        @status[:model]
      end

      def self.print(filepath)
        @queue << filepath
      end

      def self.test
        @queue << '/usr/share/cups/data/testprint'
      end

      private
        def self.start_monitor!
          t = Thread.new do
            loop do
              if @queue.empty?
                @status[:error] = @device.error || ''
                @status[:model] = @device.model
              else
                begin
                  `lpr #{@queue[0]} >> #{File.expand_path(Smartware::Logging.logfile)} 2>&1` # Turn lpr-log from STDOUT to smartware
                  Smartware::Logging.logger.info "Printed #{@queue[0]}"
                  @queue.shift
                  sleep 5
                rescue => e
                  Smartware::Logging.logger.error e.message
                  Smartware::Logging.logger.error e.backtrace.join("\n")
                end
              end
              sleep 0.2
            end
          end
        end

    end
  end
end

DRb.start_service('druby://localhost:6005', Smartware::Interface::Printer)
DRb.thread.join

