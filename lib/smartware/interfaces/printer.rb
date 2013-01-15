module Smartware
  module Interface
    class Printer < Interface

      def initialize(config)
        super

        @configured = false
        @status = {:error => ''}
        @queue = []

        @session = Thread.new &method(:poll)
        Smartware::Logging.logger.info 'Printer monitor started'
        @configured = true
      rescue => e
        @configured = false
        Smartware::Logging.logger.error "Printer initialization failed: #{e.to_s}"
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

      def print(filepath)
        @queue << filepath unless filepath.nil?
      end

      def test
        @queue << '/usr/share/cups/data/testprint'
      end

      private

      def poll
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
  end
end
