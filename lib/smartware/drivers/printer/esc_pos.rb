require "serialport"

module Smartware
  module Driver
    module Printer

      class EscPos
        QUERY = [
          0x10, 0x04, 20, # Transmit Full Status
        ].pack("C*")

        MODEL_QUERY = [
          0x1D, 0x49, 0x31,  # Printer model ID
        ].pack("C*")

        VERSION_QUERY = [
          0x1D, 0x49, 0x33,   # Printer ROM version
        ].pack("C*")

        attr_reader :error, :model, :version, :status

        def initialize(config)
          @sp = SerialPort.new config["port"], 115200, 8, 1, SerialPort::NONE
          @sp.read_timeout = 500

          @error = nil
          @status = :ready
          @model = ''
          @version = ''
          @buf = "".force_encoding("BINARY")
        end

        def query
          begin
            paper_status, user_status, recoverable, unrecoverable = do_query

            raise "no response to query" if paper_status.nil?

            if unrecoverable != 0
              @status = :error

              @error = Interface::Printer::HARDWARE_ERROR
            elsif (paper_status & 1) != 0
              @status = :error
              @error = Interface::Printer::OUT_OF_PAPER

            elsif (recoverable != 0) || ((user_status & 3) != 0)
              @status = :transient_error
              @error = Interface::Printer::HARDWARE_ERROR

            elsif (paper_status & 4) != 0
              @status = :warning
              @error = Interface::Printer::PAPER_NEAR_END

            else
              @status = :ready
              @error = nil
            end

            @sp.write MODEL_QUERY
            printer_model = read_response(1)
            raise "no response to model query" if printer_model.nil?

            printer_model, = printer_model.unpack("C*")

            @sp.write VERSION_QUERY
            printer_version = read_response(4)
            raise "no response to version querty" if printer_version.nil?

            @model = "ESC/POS Printer #{printer_model.to_s 16}"
            @version = "ROM #{printer_version.inspect}"

          rescue => e
            Smartware::Logging.logger.warn "Printer communication error: #{e}"
            e.backtrace.each { |line| Smartware::Logging.logger.warn line }

            @error = Interface::Printer::COMMUNICATION_ERROR
            @status = :error
          end
        end

        def print(data)
          start = Time.now

          data.force_encoding('BINARY')

          begin
            data.split(/(\n)/, -1).each do |line|
              @sp.write line

              loop do
                now = Time.now
                # timeout exceeded
                return if now - start > 10

                status = do_query
                next if status.nil?

                paper_status, user_status, recoverable, unrecoverable = status

                # Unrecoverable error or out of paper
                return if unrecoverable != 0 || (paper_status & 1) != 0

                # No error - continue printing
                break if (recoverable == 0) && ((user_status & 3) == 0)
              end
            end

            loop do
              now = Time.now
              # timeout exceeded
              return if now - start > 10

              status = do_query
              next if status.nil?

              paper_status, user_status, recoverable, unrecoverable = status

              # paper not in motion
              break if (user_status & 8) == 0
            end

          rescue => e
            Smartware::Logging.logger.error "Printer communication error: #{e}"
            e.backtrace.each { |line| Smartware::Logging.logger.error line }
          end
        end

        def new_render
          Render.new
        end

        private

        def do_query
          # flush driver buffer
          read_response(65536, 0)
          @buf.clear

          @sp.write QUERY
          response = read_response(6).unpack("nC*")
          return nil if response.nil?

          magic, *rest = response
          raise "invalid magic: #{magic.to_s 16}. Response: #{response}, buffer: #{@buf}" if magic != 0x100F

          rest
        end

        def read_response(bytes, timeout = 1.0)
          while @buf.length < bytes
            return nil if IO.select([ @sp ], [], [], timeout).nil?

            @buf << @sp.sysread(128)
          end

          @buf.slice! 0...bytes
        end
      end

      class Render < Redcarpet::Render::Base
        START_PAGE = [
          0x1B, 0x40,     # Initialize the printer
          0x1B, 0x52, 0x00, # Set characters set: USA
          0x1B, 0x74, 0x17, # Select code code: 866
          0x1B, 0x78, 0x02, # High quality
        ].pack("C*")

        END_PAGE = [
          0x1C, 0xC0, 0xAA, 0x0F, 0xEE, 0x0B, 0x34, # Total cut and automatic paper moving back
        ].pack("C*")

        ALT_FONT  = 1
        BOLD    = 8
        DOUBLEH   = 16
        DOUBLEW   = 32
        SCRIPT  = 64
        UNDERLINE = 128


        def block_code(code, language)
          code
        end

        def block_quote(text)
          text
        end

        def block_html(text)
          text
        end

        def header(text, level)
          styled(DOUBLEW | DOUBLEH) { text } + "\n"
        end

        def hrule
          "_" * 32 + "\n"
        end

        def list(text, type)
          items = text.split "\x01"
          out = ""

          case type
          when :unordered

            items.each_with_index do |text, index|
              out << "- #{text}\n"
            end

          when :ordered

            items.each_with_index do |text, index|
              out << "#{index + 1}. #{text}\n"
            end
          end

          out
        end

        def list_item(text, type)
          "#{text}\x01"
        end

        def paragraph(text)
          text + "\n\n"
        end

        def table(header, body)
          ""
        end

        def tablerow(text)
          ""
        end

        def tablecell(text, align)
          ""
        end

        def autolink(link, type)
          link
        end

        def codespan(text)
          text
        end

        def double_emphasis(text)
          styled(BOLD) { text }
        end

        def emphasis(text)
          styled(SCRIPT) { text }
        end

        def image(link, title, alt)
          alt
        end

        def linebreak
          "\n"
        end

        def link(link, title, content)
          content
        end

        def raw_html(text)
          ""
        end

        def triple_emphasis(text)
          styled(UNDERLINE) { text }
        end

        def normal_text(text, keep_newlines = false)
          text.encode!("CP866")

          unless keep_newlines
            text.gsub! "\n", " "
          end

          text
        end

        def doc_header
          @mode = 0

          START_PAGE + set_mode
        end

        def doc_footer
          END_PAGE
        end

        private

        def set_mode
          [ 0x1B, 0x21, @mode ].pack("C*")
        end

        def styled(bit, &block)
          out = ""

          old_mode = @mode
          @mode |= bit

          out << set_mode if @mode != old_mode

          out << yield

          if @mode != old_mode
            @mode = old_mode
            out << set_mode
          end

          out
        end
      end
    end
  end
end
