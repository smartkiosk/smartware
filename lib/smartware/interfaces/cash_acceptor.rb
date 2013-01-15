require 'drb'


module Smartware
  module Interface
    class CashAcceptor < Interface

      def initialize(config)
        super

        @limit = nil
        @banknotes = {}
        @banknotes.default = 0

        @status_mutex = Mutex.new
        @status = {
          casette: false,
          accepting: false,
          error: '',
          model: '',
          version: ''
        }

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

      def configured?
        true
      end

      def error
        self.status[:error]
      end

      def model
        self.status[:model]
      end

      def version
        self.status[:version]
      end

      def accepting
        self.status[:accepting]
      end

      def status
        @status_mutex.synchronize { @status }
      end

      def banknotes
        @status_mutex.synchronize { @banknotes }
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

        @status_mutex.synchronize do
          @status[:accepting] = true
        end
      end

      def execute_get_money
        res = @device.current_banknote

        case res
        when Integer
          if limit_satisfied(self.cashsum + res)
            @device.stack
            @status_mutex.synchronize do
              @banknotes[res] += 1
            end
            Smartware::Logging.logger.info "Cash acceptor bill stacked, #{res}"
          else
            @device.return
            Smartware::Logging.logger.info "Cash acceptor limit violation, return #{res}"
          end

        when String
          Smartware::Logging.logger.error "Cash acceptor error #{res}"

          @status_mutex.synchronize do
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

        @status_mutex.synchronize do
          @status[:accepting] = false
        end
      end

      def execute_monitor

        error = @device.error || ''
        model = @device.model
        version = @device.version
        cassette = @device.cassette?

        @status_mutex.synchronize do
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
            send :"execute_#{command}"
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
            @commands.push :monitor

            if self.accepting
              @commands.push :get_money
              sleep 0.5
            else
              sleep 5
            end
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
