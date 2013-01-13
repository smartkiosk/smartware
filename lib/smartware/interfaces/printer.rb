require 'drb'

module Smartware
  module Interface

    module Printer

      @configured = false
      @status = {:error => ''}
      @queue = []

      def self.configure!(port=nil, driver=nil)
        @device = Smartware::Driver::Printer.const_get(
            Smartware::Service.config['printer_driver']).new(
            Smartware::Service.config['printer_port'])
        @session.kill if @session and @session.alive?
        @session = self.start_monitor!
        Smartware::Logging.logger.info 'Printer monitor started'
        @configured = true
      rescue => e
        @configured = false
        Smartware::Logging.logger.error "Printer initialization failed: #{e.to_s}"
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

      def self.version
        @status[:version]
      end

      def self.print(filepath)
        @queue << filepath unless filepath.nil?
      end

      def self.test
        @queue << '/usr/share/cups/data/testprint'
      end

      private
        def self.start_monitor!
          t = Thread.new do
            loop do
              begin
                if @queue.empty?
                  @status[:error] = @device.error || ''
                  @status[:model] = @device.model
                  @status[:version] = @device.version
                else
                    `lpr #{@queue[0]}`
                    Smartware::Logging.logger.info "Printed #{@queue[0]}"
                    @queue.shift
                    sleep 5
                end
              rescue => e
                Smartware::Logging.logger.error e.message
                Smartware::Logging.logger.error e.backtrace.join("\n")
              end
              sleep 0.2
            end
          end
        end

      self.configure!
    end
  end
end

DRb.start_service('druby://localhost:6005', Smartware::Interface::Printer)
DRb.thread.join

