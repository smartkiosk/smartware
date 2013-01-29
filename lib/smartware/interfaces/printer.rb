module Smartware
  module Interface
    class Printer < Interface

      HARDWARE_ERROR = 1
      COMMUNICATION_ERROR = 2
      OUT_OF_PAPER = 3
      PAPER_NEAR_END = 1000

      def initialize(config, service)
        super

        @printer_mutex = Mutex.new
        Thread.new &method(:poll)
        @render = @device.new_render
        @markdown = Redcarpet::Markdown.new(@render)
      end

      def receive_request(command, *args)
        case command
        when "test", "print", "print_markdown", "print_text"
          EventMachine.defer do
            ret = false
            job_id = args.shift
            publish_event :started, job_id

            begin
              ret = send command.to_sym, *args
            rescue => e
              Logging.logger.error "Error during processing of print job #{job_id}: #{e}"
              e.backtrace.each { |line| Logging.logger.error line }
            ensure
              if ret
                publish_event :completed, job_id
              else
                publish_event :failed, job_id
              end
            end
          end
        else
          super
        end
      end

      def test
        print_markdown <<-EOS
Smartware: **#{Smartware::VERSION}**

Driver:  **#{@config["driver"]}**

Model:   **#{@device.model}**

Version: **#{@device.version}**

EOS
      end

      def print(file, max_time = 30)
        File.open(file, "r") do |io|
          print_markdown io.read, max_time
        end
      end

      def print_markdown(text, max_time = 30)
        do_print @markdown.render(text), max_time
      end

      def print_text(text, max_time = 30)
        data = "".force_encoding("BINARY")
        data << @render.doc_header.force_encoding("BINARY") if @render.respond_to? :doc_header
        data << @render.normal_text(text, true).force_encoding("BINARY") if @render.respond_to? :normal_text
        data << @render.linebreak.force_encoding("BINARY") if @render.respond_to? :linebreak
        data << @render.doc_footer.force_encoding("BINARY") if @render.respond_to? :doc_footer

        do_print data, max_time
      end

      private
      def do_print(text, max_time)
        Smartware::Logging.logger.info "Started printing"

        started = Time.now

        @printer_mutex.synchronize do
          query_printer

          loop do
            case @device.status
            when :ready, :warning
              @device.print text

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

        self.error.nil? || self.error >= 1000
      end

      def query_printer
        @device.query
        update_status :error, @device.error
        update_status :model, @device.model
        update_status :version, @device.version
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
