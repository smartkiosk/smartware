module Smartware
  module Interface
    class Printer < Interface

      HARDWARE_ERROR = 1
      COMMUNICATION_ERROR = 2
      OUT_OF_PAPER = 3
      PAPER_NEAR_END = 1000

      def initialize(config)
        super

        @printer_mutex = Mutex.new
        Thread.new &method(:poll)
        @markdown = Redcarpet::Markdown.new(@device.new_render)
      end

      def test
        print_text <<-EOS
Smartware: **#{Smartware::VERSION}**

Driver:  **#{@config["driver"]}**

Model:   **#{@device.model}**

Version: **#{@device.version}**

EOS
      end

      def print(file, max_time = 30)
        File.open(file, "r") do |io|
          print_text io.read, max_time
        end
      end

      def print_text(text, max_time = 30)
        Smartware::Logging.logger.info "Started printing"

        started = Time.now

        @printer_mutex.synchronize do
          query_printer

          loop do
            case @device.status
            when :ready, :warning
              @device.print @markdown.render(text)

              query_printer

              break

            when :transient_error
              Smartware::Logging.logger.warn "Transient error #{self.error}."

              now = Time.now
              break if now - started > max_time

              sleep 0.5
            when :error
              Smartware::Logging.logger.warn "Error #{self.error}."

              break
            end
          end
        end

        Smartware::Logging.logger.info "Completed"

        self.error.nil? || self.error < 1000
      end

      private

      def query_printer
        @device.query
        update_status do
          @status[:error] = @device.error
          @status[:model] = @device.model
          @status[:version] = @device.version
        end
      end

      def poll
        loop do
          begin
            @printer_mutex.synchronize &method(:query_printer)
            sleep 1
          rescue => e
            Smartware::Logging.logger.error e.message
            Smartware::Logging.logger.error e.backtrace.join("\n")
          end
        end
      end
    end
  end
end
