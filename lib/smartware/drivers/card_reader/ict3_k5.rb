require "smartware/drivers/common/sankyo_connection"

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

        def initialize(config)
          @ready = false
          @accepting = false

          @port = SerialPort.new(config["port"], 115200, 8, 1, SerialPort::EVEN)
          @port.flow_control = SerialPort::HARD

          @connection = EventMachine.attach @port, SankyoConnection
          @connection.initialize_device = method :initialize_device
        end

        def model
          "ICT3K5"
        end

        def version
          ""
        end

        def ready?
          @ready
        end

        def accepting?
          @accepting
        end

        def accepting=(accepting)
          if accepting
            set_led :green
            resp = @connection.command 0x3A, 0x30
          else
            set_led :red
            resp = @connection.command 0x3A, 0x31
          end

          translate_response resp

          @accepting = accepting
        end

        def eject
          resp = @connection.command 0x33, 0x30
          translate_response resp

          self
        end

        def capture
          resp = @connection.command 0x33, 0x31
          translate_response resp

          self
        end

        def status
          return :not_ready if !ready?

          resp = @connection.command 0x31, 0x30
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
            resp = @connection.command 0x36, track
            translate_response resp if resp.nil?

            if resp.positive?
              resp.response[4..-1]
            else
              nil
            end
          end
        end

        private

        def complete_init(response)
          if response.nil?
            Smartware::Logging.logger.warn "ICT3K5: initialization error"
          elsif response.negative?
            Smartware::Logging.logger.warn "ICT3K5: initialization negative: #{response.response}"
          else
            Smartware::Logging.logger.info "ICT3K5: initialization: #{response.response}"
            @ready = true
            set_led :red
          end
        end

        def initialize_device
          @connection.command 0x30, # Initialize
                              0x30, # Eject card,
                              0x33, 0x32, 0x34, 0x31, 0x30, # Compatibility nonsense
                              0x30, # Power down card
                              0x31, # Identify reader
                              0x30, # Eject card on DTR low
                              0x30, # Turn off capture counter
                              &method(:complete_init)
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

          @connection.command(0x35, code) {}
        end

        def translate_response(response)
          if response.nil?
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
      end
    end
  end
end
