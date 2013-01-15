require 'drb'


module Smartware
  module Interface
    class CashAcceptor < Interface

      def initialize(config)
        super

        @limit = nil
        @banknotes = Hash.new do |hash, key|
          hash[key] = 0
        end

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

        @banknotes = {}

        if limit_min.nil? || limit_max.nil?
          @limit = nil
        else
          @limit = limit_min..limit_max
        end

        @commands.push :open
        @commands.push :get_money
      end

      def close_session
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
        status = self.status

        status[:error] = @device.error || ''
        status[:model] = @device.model
        status[:version] = @device.version
        status[:cassette] = @device.cassette?

        self.status = status
      end

      def dispatch_commands
        loop do
          command = @commands.pop

          send :"execute_#{command}"
        end
      end

      def periodic
        loop do
          @commands.push :monitor

          if self.accepting
            @commands.push :get_money
            sleep 0.5
          else
            sleep 5
          end
        end
      end
    end
  end
end
