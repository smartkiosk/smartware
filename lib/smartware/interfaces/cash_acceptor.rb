module Smartware
  module Interface
    class CashAcceptor < Interface

      DROP_CASETTE_FULL = 1
      DROP_CASETTE_OUT_OF_POSITION = 2
      VALIDATOR_JAMMED = 3
      DROP_CASETTE_JAMMED = 4
      CHEATED = 5
      PAUSE = 6
      BILL_VALIDATOR_FAILURE = 7
      STACK_MOTOR_FAILURE = 8
      TRANSPORT_MOTOR_SPEED_FAILURE = 9
      TRANSPORT_MOTOR_FAILURE = 10
      ALIGNING_MOTOR_FAILURE = 11
      INITIAL_CASETTE_STATUS_FAILURE = 12
      OPTIC_CANAL_FAILURE = 13
      MAGNETIC_CANAL_FAILURE = 14
      CAPACITANCE_CANAL_FAILURE = 15
      COMMUNICATION_ERROR = 16

      class BillType
        attr_reader :value
        attr_reader :country

        def initialize(value, country)
          @value = value
          @country = country
        end

        def to_s
          "#{@country}:#{@value}"
        end
      end

      def initialize(config, service)
        super

        @device.open = method :device_open
        @device.closed = method :device_closed
        @device.escrow = method :escrow
        @device.stacked = method :stacked
        @device.returned = method :returned
        @device.status = method :status_changed

        @limit = nil
        @banknotes = {}
        @banknotes.default = 0

        update_status :casette, false
        update_status :accepting, false

        Smartware::Logging.logger.info "Cash acceptor monitor started"
      end

      def open(limit_min = nil, limit_max = nil)
        @banknotes.clear

        if limit_min.nil? || limit_max.nil?
          @limit = nil

          Smartware::Logging.logger.debug "Session open, unlimited"
        else
          @limit = limit_min..limit_max

          Smartware::Logging.logger.debug "Session open, limit: #{@limit}"
        end

        EventMachine.schedule do
          types = 0
          @device.bill_types.each_with_index do |type, index|
            next if type.nil?

            if type.country == 'RUS'
              types |= 1 << index
            end
          end

          @device.enabled_types = types
        end
      end

      def close
        Smartware::Logging.logger.debug "Session closed"

        EventMachine.schedule do
          @device.enabled_types = 0
        end

        @limit = nil
      end

      def banknotes
        @banknotes
      end

      def sum
        self.banknotes.inject(0) do |result, (key, value)|
          result + key.to_i * value.to_i
        end
      end

      def insert_casette
        @device.insert_casette
      end

      def eject_casette
        @device.eject_casette
      end

      private

      def limit_satisfied?(sum)
        @limit.nil? or @limit.include? sum
      end

      def escrow(banknote)
        limit_satisfied?(self.sum + banknote.value)
      end

      def stacked(banknote)
        value = banknote.value

        @banknotes[value] += 1

        Smartware::Logging.logger.debug "cash acceptor: bill stacked, #{value}"

        publish_event :stacked, value
      end

      def returned(banknote)
        value = banknote.value

        Smartware::Logging.logger.debug "cash acceptor: bill returned, #{value}"
      end

      def status_changed(error)
        update_status :error, error
        update_status :model, @device.model
        update_status :version, @device.version
        update_status :casette, error != DROP_CASETTE_OUT_OF_POSITION
        update_status :cashsum, sum
      end

      def device_open
        Smartware::Logging.logger.debug "Device acknowleged open"

        update_status :accepting, true
      end

      def device_closed
        Smartware::Logging.logger.debug "Device acknowleged close"

        update_status :accepting, false
      end
    end
  end
end
