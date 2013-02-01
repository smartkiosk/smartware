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
        update_status :status, :not_ready

        schedule_status
      end

      def card_inserted?
        ret = @status[:status] == :card_inserted
        update_status :error, nil
        ret
      rescue CardReaderError => e
        update_status :error, e.code
        nil
      end

      def present?
        status = @status[:status]
        ret = status == :card_inserted || status == :card_at_gate
        update_status :error, nil
        ret
      rescue CardReaderError => e
        update_status :error, e.code
        nil
      end

      def start_accepting
        @device.accepting = true
        update_status :error, nil
        true
      rescue CardReaderError => e
        update_status :error, e.code
        false
      end

      def stop_accepting
        @device.accepting = false
        update_status :error, nil
        true
      rescue CardReaderError => e
        update_status :error, e.code
        false
      end

      def eject
        @device.eject

        update_status :error, nil
        true
      rescue CardReaderError => e
        update_status :error, e.code
        false
      end

      def capture
        @device.capture
        update_status :error, nil
        true
      rescue CardReaderError => e
        update_status :error, e.code
        false
      end

      def read_magstrip
        ret = @device.read_magstrip
        update_status :error, nil
        ret
      rescue CardReaderError => e
        update_status :error, e.code
        nil
      end

      private

      def schedule_status(ret = nil)
        EventMachine.add_timer(0.5) do
          EventMachine.defer(->() { update_status :status, @device.status },
                             method(:schedule_status))
        end
      end
    end
  end
end
