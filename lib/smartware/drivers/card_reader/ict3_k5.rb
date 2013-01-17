require "serialport"
require "digest/crc16_ccitt"

module Smartware

  module Driver
    module CardReader
      class ICT3K5
        ERRORS = {
          0x00 => Interface::CardReader::COMMUNICATION_ERROR, # A given command code is unidentified
          0x01 => Interface::CardReader::COMMUNICATION_ERROR, # Parameter is not correct
          0x02 => Interface::CardReader::COMMUNICATION_ERROR, # Command execution is impossible
          0x03 => Interface::CardReader::COMMUNICATION_ERROR, # Function is not implemented
          0x04 => Interface::CardReader::COMMUNICATION_ERROR, # Command data error
          0x06 => Interface::CardReader::COMMUNICATION_ERROR, # Key for decrypting is not received
          0x10 => Interface::CardReader::CARD_JAM_ERROR,
          0x11 => Interface::CardReader::CARD_ERROR,          # Shutter error
          0x13 => Interface::CardReader::CARD_ERROR,          # Long card
          0x14 => Interface::CardReader::CARD_ERROR,          # Short card
          0x15 => Interface::CardReader::HARDWARE_ERROR,      # Flash Memory Parameter Area CRC error
          0x16 => Interface::CardReader::CARD_ERROR,          # Card position move
          0x17 => Interface::CardReader::CARD_JAM_ERROR,      # Jam error at retrieve
          0x18 => Interface::CardReader::CARD_ERROR,          # Two card error
          0x20 => Interface::CardReader::MAG_READ_ERROR,      # Parity error
          0x21 => Interface::CardReader::MAG_READ_ERROR,      # Sentinel error
          0x23 => Interface::CardReader::MAG_READ_ERROR,      # No data contents
          0x24 => Interface::CardReader::MAG_READ_ERROR,      # No stripe
          0x30 => Interface::CardReader::HARDWARE_ERROR,      # Power loss
          0x31 => Interface::CardReader::COMMUNICATION_ERROR, # DTR low
          0x39 => Interface::CardReader::HARDWARE_ERROR,      # Fan failure
          0x40 => Interface::CardReader::CARD_ERROR,          # Pull out error
          0x43 => Interface::CardReader::CARD_ERROR,          # IC positioning error
          0x50 => Interface::CardReader::HARDWARE_ERROR,      # Capture counter overflow
          0x60 => Interface::CardReader::ICC_ERROR,           # Abnormal VCC condition
          0x61 => Interface::CardReader::ICC_ERROR,           # ATR error
          0x62 => Interface::CardReader::ICC_ERROR,           # Invalid ATR error
          0x63 => Interface::CardReader::ICC_ERROR,           # No response
          0x64 => Interface::CardReader::ICC_ERROR,           # Communication error
          0x65 => Interface::CardReader::ICC_ERROR,           # Not activated
          0x66 => Interface::CardReader::ICC_ERROR,           # Unsupported card
          0x69 => Interface::CardReader::ICC_ERROR,           # Unsupported card
          0x73 => Interface::CardReader::HARDWARE_ERROR,      # EEPROM error
          0xB0 => Interface::CardReader::COMMUNICATION_ERROR  # Not received initialize
        }

        class CRC < Digest::CRC16CCITT
          INIT_CRC = 0x0000
        end

        class CommandResponse
          def initialize(response)
            @response = response
          end

          def error?
            @response.nil? || (@response[0] != "P" && @response[0] != "N")
          end

          def positive?
            @response[0] == "P"
          end

          def negative?
            @response[0] == "N"
          end

          def response
            @response[1..-1]
          end
        end

        STX = 0xF2
        ACK = 0x06
        NAK = 0x15

        def initialize(config)
          @config = config

          @port = SerialPort.new(config["port"], 115200, 8, 1, SerialPort::EVEN)

          @state = :not_ready
          @event_read, @event_write = IO.pipe
          @read_buf = ""
          @write_buf = ""
          @command_queue = Queue.new
          @status_mutex = Mutex.new
          @active_command = nil
          @active_block = nil
          @start_time = nil
          @retries = nil
          @ready = false
          @accepting = false

          Thread.new &method(:dispatch)
        end

        def model
          "ICT3K5"
        end

        def version
          ""
        end

        def ready?
          @status_mutex.synchronize { @ready }
        end

        def accepting?
          @status_mutex.synchronize { @accepting }
        end

        def accepting=(accepting)
          if accepting
            set_led :green
            resp = command 0x3A, 0x30
          else
            set_led :red
            resp = command 0x3A, 0x31
          end

          translate_response resp

          @status_mutex.synchronize { @accepting = accepting }
        end

        def eject
          resp = command 0x33, 0x30
          translate_response resp

          self
        end

        def capture
          resp = command 0x33, 0x31
          translate_response resp

          self
        end

        def status
          return :not_ready if !ready?

          resp = command 0x31, 0x30
          translate_response resp

          case resp.response[2..3]
          when "00"
            :ready

          when "01"
            :card_at_gate

          when "02"
            :card_inserted

          else
            :not_ready
          end
        end

        def read_magstrip
          [ 0x31, 0x32, 0x33, 0x34 ].map! do |track|
            resp = command 0x36, track
            translate_response resp if resp.error?

            if resp.positive?
              resp.response[4..-1]
            else
              nil
            end
          end
        end

        private

        def command(*args, &block)
          if block_given?
            @command_queue.push [ args, block ]
            @event_write.write "\x01"
          else
            queue = Queue.new
            command(*args) { |response| queue.push response }
            queue.pop
          end
        end

        def translate_response(response)
          if response.error?
            raise Interface::CardReader::CardReaderError.new(
              "communication error",
              Interface::CardReader::COMMUNICATION_ERROR
            )
          elsif response.negative?
            error = response.response[0..1].to_i(16)
            if ERRORS.include? error
              translated_error = ERRORS[error]
            else
              translated_error = Interface::CardReader::HARDWARE_ERROR
            end

            raise Interface::CardReader::CardReaderError.new(
              "command failed: #{error}",
              translated_error
            )
          end
        end

        def set_led(color)
          code = nil

          case color
          when :off
            code = 0x30

          when :green
            code = 0x31

          when :red
            code = 0x32

          when :orange
            code = 0x33
          end

          command(0x35, code) do |resp|

          end
        end

        def complete_init(response)
          if response.error?
            Smartware::Logging.logger.info "ICT3K5: initialization error"
          elsif response.negative?
            Smartware::Logging.logger.info "ICT3K5: initialization negative: #{response.response}"
          else
            Smartware::Logging.logger.info "ICT3K5: initialization: #{response.response}"
            @status_mutex.synchronize { @ready = true }
            set_led :red
          end
        end

        def run_periodic
          if @start_time.nil?
            elapsed = nil
          else
            elapsed = Time.now - @start_time
          end

          case @state
          when :not_ready
            if @port.dsr == 1

              Smartware::Logging.logger.info "ICT3K5: DSR active, initializing"

              @state = :accepting

              flushed = []

              command 0x30, # Initialize
                      0x30, # Eject card,
                      0x33, 0x32, 0x34, 0x31, 0x30, # Compatibility nonsense
                      0x30, # Power down card
                      0x31, # Identify reader
                      0x30, # Eject card on DTR low
                      0x30, # Turn off capture counter
                      &method(:complete_init)

              flushed.each do |(command, block)|
                block.call CommandResponse.new(error: "timeout")
              end
            end

          when :waiting_ack
            if elapsed > 0.3
              Smartware::Logging.logger.info "ICT3K5: ACK timeout"
              retry_or_fail
            end

          when :reading_response
            if elapsed > 20
              Smartware::Logging.logger.info "ICT3K5: command timeout"
              retry_or_fail
            end
          end

          if @port.dsr == 0
            @status_mutex.synchronize do
              @ready = false
              @accepting = false
            end

            if !@active_command.nil?
              Smartware::Logging.logger.info "ICT3K5: DSR fall"

              fail_command
            end

            until @command_queue.empty?
              unpacked, block = @command_queue.pop(true)

              block.call CommandResponse.new(nil)
            end
          end
        end

        def start_execution
          @event_read.readbyte

          unpacked, @active_block = @command_queue.pop
          @active_command = frame_command(unpacked)

          @write_buf << @active_command
          @start_time = Time.now
          @state = :waiting_ack
          @retries = 8
        end

        def complete_command(response)
          block = @active_block

          @state = :accepting
          @active_command = nil
          @active_block = nil

          Smartware::Logging.logger.info "ICT3K5: completing command"

          block.call CommandResponse.new(response)
        end

        def fail_command
          block = @active_block

          @state = :accepting
          @active_command = nil
          @active_block = nil

          Smartware::Logging.logger.info "ICT3K5: failing command"

          block.call CommandResponse.new(nil)
        end

        def retry_or_fail
          if @retries == 0
            fail_command
          else
            @retries -= 1
            @start_time = Time.now
            @state = :waiting_ack
            @write_buf << @active_command
          end
        end

        def frame_command(bytes)
          data = [ STX, bytes.length + 1 ].pack("Cn")
          data << "C"
          data << bytes.pack("C*")

          crc = CRC.new
          crc << data
          data << [ crc.checksum ].pack("n")

          data
        end

        def read_chunk
          @read_buf << @port.read_nonblock(8192)
        rescue IO::WaitReadable
        end

        def write_chunk
          bytes = @port.write_nonblock @write_buf
          @write_buf.slice! 0, bytes

        rescue IO::WaitWritable
        end

        def handle_input
          until @read_buf.empty? do
            case @state
            when :waiting_ack
              initial_byte = @read_buf.slice!(0, 1).ord

              case initial_byte
              when ACK
                Smartware::Logging.logger.info "ICT3K5: ACK"

                @state = :reading_response
                @start_time = Time.now

              when NAK
                Smartware::Logging.logger.info "ICT3K5: NAK"

                retry_or_fail

              else
                Smartware::Logging.logger.info "ICT3K5: garbage on line: #{initial_byte}"
              end

            when :reading_response
              break if @read_buf.length < 5

              leading_byte, length = @read_buf[0..2].unpack("Cn")
              if leading_byte != STX
                Smartware::Logging.logger.info "ICT3K5: garbage on line: #{leading_byte}"

                @read_buf.slice! 0, 1
                next
              end

              full_length = 5 + length

              break if @read_buf.length < full_length

              message = @read_buf.slice! 0, full_length
              sum, = message.slice!(full_length - 2, 2).unpack("n")
              crc = CRC.new
              crc << message
              if sum == crc.checksum
                Smartware::Logging.logger.info "ICT3K5: message checksum ok, ACK and process"
                @write_buf << ACK.chr
                complete_command message[3..-1]
              else
                Smartware::Logging.logger.info "ICT3K5: message checksum invalid, NAK"
                @write_buf << NAK.chr
              end

            else
              break
            end
          end
        end

        def dispatch
          loop do
            begin
              run_periodic

              read_set = [ @port ]
              write_set = []

              read_set << @event_read if @state == :accepting
              write_set << @port unless @write_buf.empty?

              read_set, write_set, = IO.select read_set, write_set, [], 1

              unless read_set.nil?
                start_execution if read_set.include? @event_read
                read_chunk if read_set.include? @port
                write_chunk if write_set.include? @port
              end

              handle_input
            rescue => e
              Smartware::Logging.logger.error "Error in ICT3K5 dispatch:"
              Smartware::Logging.logger.error e.to_s
              e.backtrace.each do |line|
                Smartware::Logging.logger.error line
              end
            end
          end
        end
      end
    end
  end
end
