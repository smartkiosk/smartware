module Smartware
  module Interface
    class CardReader < Interface
      COMMUNICATION_ERROR = 1
      HARDWARE_ERROR      = 2
      CARD_JAM_ERROR      = 3
      CARD_ERROR          = 4
      MAG_READ_ERROR      = 5
      ICC_ERROR           = 6

      class CardReaderError < RuntimeError
        attr_reader :code

        def initialize(message, code)
          super(message)

          @code = code
        end
      end

      def initialize(config, service)
        super

        update_status :model, @device.model
        update_status :version, @device.version
        update_status :card_inserted, false, nil, nil, nil

        @state = :inactive
        @open = false
        @mutex = Mutex.new
        @cvar = ConditionVariable.new

        schedule_status
      end

      def open
        @mutex.synchronize do
          @open = true
          @cvar.wait(@mutex)
        end
      end

      def close
        @mutex.synchronize do
          @open = false
          @cvar.wait(@mutex)
        end
      end

      def card_inserted
        @status[:card_inserted]
      end

      private

      def poll
        open = nil
        @mutex.synchronize do
          open = @open
          @cvar.broadcast
        end

        begin
          status = @device.status

          case @state
          when :failure
            if status == :ready
              @state = :inactive
              update_status :error, nil
            end

          when :inactive
            if open
              @device.accepting = true
              @state = :waiting_card
            end

          when :waiting_card
            if !open
              @device.accepting = false
              @device.eject rescue nil
              @state = :waiting_eject

            elsif status == :card_inserted
              @state = :card_inside
              @device.accepting = false

              track1, track2, = @device.read_magstrip
              if track1.nil? || track2.nil?
                @device.eject rescue nil
                @state = :waiting_eject
              else
                update_status :card_inserted, true, false, track1, track2
              end
            end

          when :card_inside
            if !open || status != :card_inserted
              update_status :card_inserted, false, nil, nil, nil
              @device.eject rescue nil
              @state = :waiting_eject
            end

          when :waiting_eject
            if status == :ready || status == :not_ready
              if open
                @state = :waiting_card
                @device.accepting = true
              else
                @state = :inactive
              end
            end
          end
        rescue CardReaderError => e
          Logging.logger.error "Card reader error: #{e}" unless @state == :failure

          begin
            @device.eject
            @device.accepting = false
          rescue CardReaderError => e
          end

          @state = :failure
          update_status :error, e.code
        end
      end

      def schedule_status(ret = nil)
        EventMachine.add_timer(0.1) do
          EventMachine.defer(method(:poll),
                             method(:schedule_status))
        end
      end
    end
  end
end
