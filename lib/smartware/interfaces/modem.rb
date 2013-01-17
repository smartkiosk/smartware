module Smartware
  module Interface
    class Modem < Interface
      MODEM_NOT_AVAILABLE = 1

      def initialize(config)
        super

        update_status do
          @status[:balance] = ''
          @status[:signal_level] = ''
        end

        @session = Thread.new &method(:poll)
        Smartware::Logging.logger.info 'Modem monitor started'
      end

      def balance
        self.status[:balance]
      end

      def signal_level
        self.status[:signal_level]
      end

      private

      def poll
        begin
          loop do
            @device.tick

            update_status do
              @status[:signal_level] = @device.signal_level
              @status[:model] = @device.model
              @status[:version] = @device.version
              @status[:error] = @device.error
              @status[:balance] = @device.balance
            end
          end
        rescue => e
          Smartware::Logging.logger.error e.message
          Smartware::Logging.logger.error e.backtrace.join("\n")
        end
      end
    end
  end
end

