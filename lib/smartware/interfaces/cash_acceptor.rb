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

      def initialize(config)
        super

        @limit = nil
        @banknotes = {}
        @banknotes.default = 0

        update_status do
          @status[:casette] = true
        end

        @accepting = false
        @commands = Queue.new
        @commands.push :close

        Thread.new &method(:dispatch_commands)
        Thread.new &method(:periodic)
        Smartware::Logging.logger.info "Cash acceptor monitor started"
      end

      def open_session(limit_min, limit_max)
        @banknotes.clear

        if limit_min.nil? || limit_max.nil?
          @limit = nil

          Smartware::Logging.logger.info "Session open, unlimited"
        else
          @limit = limit_min..limit_max

          Smartware::Logging.logger.info "Session open, limit: #{@limit}"
        end

        @commands.push :open
        @commands.push :get_money
      end

      def close_session
        Smartware::Logging.logger.info "Session closed"

        @commands.push :close
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

      def limit_satisfied(sum)
        @limit.nil? or @limit.include? sum
      end

      def execute_open
        @device.reset
        @device.accept
        Smartware::Logging.logger.info "Cash acceptor open"

        @accepting = true
      end

      def execute_get_money
        res = @device.current_banknote

        case res
        when Integer
          if limit_satisfied(self.cashsum + res)
            @device.stack
            update_status do
              @banknotes[res] += 1
            end
            Smartware::Logging.logger.info "Cash acceptor bill stacked, #{res}"
          else
            @device.return
            Smartware::Logging.logger.info "Cash acceptor limit violation, return #{res}"
          end

        when String
          Smartware::Logging.logger.error "Cash acceptor error #{res}"

          update_status do
            @status[:error] = res
          end
        end

        if !@limit.nil? && @limit.end > 0 && @limit.end == self.cashsum
          # Close cash acceptor if current cashsum equal max-limit

          execute_close
        end
      end

      def execute_close
        @device.cancel_accept
        Smartware::Logging.logger.info "Cash acceptor close"

        @accepting = false
      end

      def execute_monitor
        error = @device.error
        model = @device.model
        version = @device.version
        cassette = @device.cassette?

        update_status do
          @status[:error] = error
          @status[:model] = model
          @status[:version] = version
          @status[:cassette] = cassette
        end
      end

      def dispatch_commands
        loop do
          command = @commands.pop

          begin
            start = Time.now

            send :"execute_#{command}"

            complete = Time.now
            if complete - start > 1
              Smartware::Logging.logger.warn "#{command} has been running for #{complete - start} seconds."
            end

          rescue => e
            Smartware::Logging.logger.error "Execution of #{command} failed:"
            Smartware::Logging.logger.error e.to_s
            e.backtrace.each do |line|
              Smartware::Logging.logger.error line
            end
          end
        end
      end

      def periodic
        loop do
          begin
            if @commands.empty?
              @commands.push :monitor
              @commands.push :get_money if @accepting
            end

            sleep 0.5
          rescue => e
            Smartware::Logging.logger.error "Error in periodic failed:"
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
