module Smartware
  module Interface

    class Modem < Interface
      def initiaalize(config)
        super

        @configured = false
        @status = {}

        @session = Thread.new &method(:poll)
        Smartware::Logging.logger.info 'Modem monitor started'
        @configured = true
      rescue => e
        Smartware::Logging.logger.error e.message
        Smartware::Logging.logger.error e.backtrace.join("\n")
        @configured = false
      end

      def configured?
        @configured
      end

      def error
        @status[:error]
      end

      def model
        @status[:model]
      end

      def version
        @status[:version]
      end

      def balance
        @status[:balance]
      end

      def signal_level
        @status[:signal_level]
      end

      private

      def poll
        begin
          loop do
            @device.tick

            @status[:signal_level] = @device.signal_level
            @status[:model] = @device.model
            @status[:version] = @device.version
            @status[:error] = @device.error || ''
            @status[:balance] = @device.balance
          end
        rescue => e
          Smartware::Logging.logger.error e.message
          Smartware::Logging.logger.error e.backtrace.join("\n")
        end
      end
    end
  end
end

