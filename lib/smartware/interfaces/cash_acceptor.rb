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

      def initialize(config)
        super

        @device.escrow = method :escrow
        @device.stacked = method :stacked
        @device.returned = method :returned
        @device.status = method :status

        @limit = nil
        @banknotes = {}
        @banknotes.default = 0

        update_status do
          @status[:casette] = true
        end

        Smartware::Logging.logger.info "Cash acceptor monitor started"
      end

      def open_session(limit_min, limit_max)
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

      def close_session
        Smartware::Logging.logger.debug "Session closed"

        EventMachine.schedule do
          @device.enabled_types = 0
        end

        @limit = nil
      end

      def banknotes
        update_status { @banknotes }
      end

      def cashsum
        self.banknotes.inject(0) do |result, (key, value)|
          result + key.to_i * value.to_i
        end
      end

      private

      def limit_satisfied?(sum)
        @limit.nil? or @limit.include? sum
      end

      def escrow(banknote)
        limit_satisfied?(self.cashsum + banknote.value)
      end

      def stacked(banknote)
        value = banknote.value

        update_status do
          @banknotes[value] += 1
        end

        Smartware::Logging.logger.debug "cash acceptor: bill stacked, #{value}"
      end

      def returned(banknote)
        value = banknote.value

        Smartware::Logging.logger.debug "cash acceptor: bill returned, #{value}"
      end

      def status(error)
        update_status do
          @status[:error] = error
          @status[:model] = @device.model
          @status[:version] = @device.version
          @status[:casette] = error != DROP_CASETTE_OUT_OF_POSITION
        end
      end
    end
  end
end
