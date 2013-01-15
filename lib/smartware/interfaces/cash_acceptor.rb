require 'drb'


module Smartware
  module Interface
    class CashAcceptor < Interface
      def initialize(config)
        super

        #
        # Init vars
        #
        @configured = false
        @no_limit = true
        @banknotes = {}
        @commands = %w(monitor)
        @status = { :cassette => true }
        @device.cancel_accept
        @session = Thread.new &method(:poll)
        Smartware::Logging.logger.info "Cash acceptor monitor started"
        @configured = true
      rescue => e
        @configured = false
        Smartware::Logging.logger.error e.message
        Smartware::Logging.logger.error e.backtrace.join("\n")
      end

      def open_session(limit_min, limit_max)
        @commands << 'open'
        @banknotes = {}
        if !limit_min.nil? && !limit_max.nil?
          @no_limit = false
          @limit_min = limit_min
          @limit_max = limit_max
        else
          @no_limit = true
        end
      end

      def close_session
        @commands << 'close'
        @limit_min = nil
        @limit_max = nil
        @no_limit = true
      end

      def configured?
        @configured
      end

      def error
        @status[:error] || ''
      end

      def status
        @status
      end

      def model
        @status[:model]
      end

      def version
        @status[:version]
      end

      def cashsum
        @banknotes.inject(0) do |result, (key, value)|
          result + key.to_i * value.to_i
        end
      end

      def self.banknotes
        @banknotes
      end

      #
      # Session private method
      #

      private

      def poll
        loop do
          case @commands[0]
            when 'open'
              @device.reset
              @device.accept
              Smartware::Logging.logger.info "Cash acceptor open: #{@commands}"

              @commands.shift
              @commands << 'get_money'
            when 'get_money'
              res = @device.current_banknote
              if res.is_a? Integer # Have a banknote
                if @no_limit or (@limit_min..@limit_max).include?(self.cashsum + res)
                  @device.stack
                  @banknotes[res] = (@banknotes[res]||0) + 1
                  Smartware::Logging.logger.info "Cash acceptor bill stacked, #{res}"
                else
                  @device.return
                  Smartware::Logging.logger.info "Cash acceptor limit violation, return #{res}"
                end
              elsif res.is_a? String # Have a error, errors always as String
                Smartware::Logging.logger.error "Cash acceptor error #{res}"
                @status[:error] = res
              end
              @device.cancel_accept if !@no_limit && (@limit_max == self.cashsum and @limit_max > 0) # Close cash acceptor if current cashsum equal max-limit

              @commands.shift
              @commands << 'get_money' if @commands.empty?
            when 'close'
              @device.cancel_accept
              Smartware::Logging.logger.info "Cash acceptor close: #{@commands}"

              @commands.shift
            when 'monitor'
              @status[:error] = @device.error || ''
              @status[:model] = @device.model
              @status[:version] = @device.version
              @status[:cassette] = @device.cassette?
              @commands.shift
            else
              @commands << 'monitor'
          end
          sleep 0.5
        end
      end
    end
  end
end
