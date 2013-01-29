require "smartware/drivers/common/ccnet_connection.rb"

module Smartware
  module Driver
    module CashAcceptor
      class CCNET
        # Commands
        RESET                  = 0x30
        GET_STATUS             = 0x31
        SET_SECURITY           = 0x32
        POLL                   = 0x33
        ENABLE_BILL_TYPES      = 0x34
        STACK                  = 0x35
        RETURN                 = 0x36
        IDENTIFICATION         = 0x37
        HOLD                   = 0x38
        SET_BARCODE_PARAMETERS = 0x39
        EXTRACT_BARCODE_DATA   = 0x3A
        GET_BILL_TABLE         = 0x41
        GET_CRC32_OF_THE_CODE  = 0x51
        DOWNLOAD               = 0x50
        REQUEST_STATISTICS     = 0x60
        ACK                    = 0x00
        DISPENCE               = 0x3C

        # States
        POWER_UP = 0x10
        POWER_UP_WITH_BILL_IN_VALIDATOR = 0x11
        POWER_UP_WITH_BILL_IN_STACKER = 0x12
        INITIALIZE = 0x13
        IDLING = 0x14
        ACCEPTING = 0x15
        STACKING = 0x17
        RETURNING = 0x18
        UNIT_DISABLED = 0x19
        HOLDING = 0x1A
        DEVICE_BUSY = 0x1B
        REJECTING = 0x1C
        DROP_CASETTE_FULL = 0x41
        DROP_CASETTE_OUT_OF_POSITION = 0x42
        VALIDATOR_JAMMED = 0x43
        DROP_CASETTE_JAMMED = 0x44
        CHEATED = 0x45
        PAUSE = 0x46
        FAILURE = 0x47
        ESCROW = 0x80
        STACKED = 0x81
        RETURNED = 0x82

        ERRORS = {
          0x41 => Interface::CashAcceptor::DROP_CASETTE_FULL,
          0x42 => Interface::CashAcceptor::DROP_CASETTE_OUT_OF_POSITION,
          0x43 => Interface::CashAcceptor::VALIDATOR_JAMMED,
          0x44 => Interface::CashAcceptor::DROP_CASETTE_JAMMED,
          0x45 => Interface::CashAcceptor::CHEATED,
          0x47 => Interface::CashAcceptor::BILL_VALIDATOR_FAILURE,
          0x50 => Interface::CashAcceptor::STACK_MOTOR_FAILURE,
          0x51 => Interface::CashAcceptor::TRANSPORT_MOTOR_SPEED_FAILURE,
          0x52 => Interface::CashAcceptor::TRANSPORT_MOTOR_FAILURE,
          0x53 => Interface::CashAcceptor::ALIGNING_MOTOR_FAILURE,
          0x54 => Interface::CashAcceptor::INITIAL_CASETTE_STATUS_FAILURE,
          0x55 => Interface::CashAcceptor::OPTIC_CANAL_FAILURE,
          0x56 => Interface::CashAcceptor::MAGNETIC_CANAL_FAILURE,
          0x5f => Interface::CashAcceptor::CAPACITANCE_CANAL_FAILURE
        }

        attr_reader   :bill_types

        attr_accessor :open, :closed, :escrow, :stacked, :returned, :status
        attr_accessor :enabled_types

        def initialize(config)
          @io = SerialPort.new(config["port"], 9600, 8, 1, SerialPort::NONE)
          @io.flow_control = SerialPort::NONE

          @connection = EventMachine.attach @io, CCNETConnection
          @connection.address = 3

          @open = nil
          @closed = nil
          @escrow = nil
          @stacked = nil
          @returned = nil
          @status = nil

          @bill_types = nil
          @identification = nil
          @enabled_types = 0

          set_poll
        end

        def model
          return nil if @identification.nil?

          @identification[0..14]
        end

        def version
          return nil if @identification.nil?

          @identification[15..26]
        end

        private

        def parse_bill_types(table)
          offset = 0
          types = Array.new(24)

          while offset < table.length
            mantissa = table.getbyte(offset + 0)
            position = table.getbyte(offset + 4)
            country  = table.slice(offset + 1, 3)

            offset += 5

            next if country == "\x00\x00\x00"

            exponent = (10 ** (position & 0x7F))

            if (position & 0x80) != 0
              value = mantissa / exponent
            else
              value = mantissa * exponent
            end

            types[offset / 5 - 1] = Interface::CashAcceptor::BillType.new value, country
          end

          types
        end

        def escrow(bill)
          ret = false

          begin
            ret = @escrow.call @bill_types[bill]
          rescue => e
            Logging.logger.error "Error in escrow: #{e}"
            e.backtrace.each { |line| Logging.logger.error line }
          end

          @connection.command(ret ? STACK : RETURN) {}
        end

        def stacked(bill)
          begin
            @stacked.call @bill_types[bill]
          rescue => e
            Logging.logger.error "Error in stacked: #{e}"
            e.backtrace.each { |line| Logging.logger.error line }
          end
        end

        def returned(bill)
          begin
            @returned.call @bill_types[bill]
          rescue => e
            Logging.logger.error "Error in returned: #{e}"
            e.backtrace.each { |line| Logging.logger.error line }
          end
        end

        def poll
          @connection.command(POLL) do |resp|
            interval = nil

            if resp.nil?
              @identification = nil
              @bill_types = nil
              interval = 5
              error = Interface::CashAcceptor::COMMUNICATION_ERROR
            else
              state = resp.getbyte(0)

              case state
              when POWER_UP,
                   POWER_UP_WITH_BILL_IN_VALIDATOR
                   POWER_UP_WITH_BILL_IN_STACKER

                Logging.logger.info "Cash acceptor powered up, initializing"

                @connection.command(RESET) {}

              when INITIALIZE, ACCEPTING, STACKING, RETURNING, REJECTING,
                   CHEATED
                # Cash acceptor is busy

              when IDLING
                if @enabled_types == 0
                  @connection.command(ENABLE_BILL_TYPES, "\x00" * 6) {}

                  begin
                    @closed.call
                  rescue => e
                    Logging.logger.error "Error in open: #{e}"
                    e.backtrace.each { |line| Logging.logger.error line }
                  end
                end

              when UNIT_DISABLED
                if @identification.nil?
                  Logging.logger.debug "Identifying acceptor"

                  @connection.command(IDENTIFICATION) do |resp|
                    @identification = resp
                    Logging.logger.debug "It's #{model}, serial #{version}"
                  end

                elsif @bill_types.nil?
                  Logging.logger.debug "Loading bill table"

                  @connection.command(GET_BILL_TABLE) do |resp|
                    @bill_types = parse_bill_types resp unless resp.nil?
                  end

                elsif @enabled_types != 0
                  mask = [
                    # Enabled types
                    0,
                    (enabled_types & 0x300) >> 2,
                    enabled_types & 0xFF,
                    # Escrow types
                    0,
                    (enabled_types & 0x300) >> 2,
                    enabled_types & 0xFF,
                  ]

                  @connection.command(ENABLE_BILL_TYPES, mask.pack("C*")) {}

                  begin
                    @open.call
                  rescue => e
                    Logging.logger.error "Error in open: #{e}"
                    e.backtrace.each { |line| Logging.logger.error line }
                  end
                else
                  interval = 0.5
                end

              when DEVICE_BUSY
                interval = resp.getbyte(1) * 0.1

              when PAUSE
                Logging.logger.warn "Cash acceptor pause"

                @connection.command(RESET) {}

              when DROP_CASETTE_FULL, DROP_CASETTE_OUT_OF_POSITION,
                   VALIDATOR_JAMMED, DROP_CASETTE_JAMMED

                error = ERRORS[state]

              when FAILURE
                detail = resp.getbyte(1)
                error = ERRORS[detail]

              when ESCROW
                escrow resp.getbyte(1)

              when STACKED
                stacked resp.getbyte(1)

              when RETURNED
                returned resp.getbyte(1)

              else # incl. HOLDING
                Logging.logger.warn "Unexpected cash acceptor state: #{state.to_s 16}"
              end
            end

            if interval.nil?
              set_poll
            else
              set_poll interval
            end

            begin
              @status.call error
            rescue => e
              Logging.logger.error "Error in status: #{e}"
              e.backtrace.each { |line| Logging.logger.error line }
            end
          end
        end

        def set_poll(interval = 0.1)
          EventMachine.add_timer(interval, &method(:poll))
        end

      end
    end
  end
end
