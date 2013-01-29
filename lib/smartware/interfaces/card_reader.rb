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
      end

      def card_inserted?
        ret = @device.status == :card_inserted
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

        sleep 0.5 while @device.status == :card_at_gate

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

      rescue CardReaderError => e
        update_status :error, e.code
        nil
      end
    end
  end
end
