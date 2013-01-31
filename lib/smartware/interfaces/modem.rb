module Smartware
  module Interface
    class Modem < Interface
      MODEM_NOT_AVAILABLE = 1

      def initialize(config, service)
        super

        update_status :balance, ''
        update_status :signal_level, ''

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

            update_status :signal_level, @device.signal_level
            update_status :model, @device.model
            update_status :version, @device.version
            update_status :error, @device.error
            update_status :balance, @device.balance
          end
        rescue => e
          Smartware::Logging.logger.error e.message
          Smartware::Logging.logger.error e.backtrace.join("\n")
        end
      end
    end
  end
end

