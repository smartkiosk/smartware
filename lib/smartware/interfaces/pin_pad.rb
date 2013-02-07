module Smartware
  module Interface
    class PinPad < Interface
      class PinPadError < RuntimeError; end

      DEVICE_NOT_READY = 1
      DEVICE_ERROR     = 2

      INPUT_PLAINTEXT  = 1

      def self.safe_proxy(*methods)
        methods.each do |method|
          class_eval <<-END
          def #{method}(*args)
            result = @device.#{method}(*args)
            update_status :error, nil
            result
          rescue PinPadError => e
            Logging.logger.error "Pin pad command failed: #\{e}"
            update_status :error, DEVICE_ERROR
            nil
          end
          END
        end
      end

      safe_proxy :wipe, :restart, :start_input, :stop_input

      def initialize(config, service)
        super

        device_not_ready

        @device.imk_source = method :imk_source
        @device.post_configuration = method :post_configuration
        @device.device_ready = method :device_ready
        @device.device_not_ready = method :device_not_ready
        @device.input_event = method :input_event

      end

      protected

      def imk_source
        imk = "000000000000000000000000000000000000000000000000"
        tmk = "12345678" + "\x00" * 16

        [ imk, tmk ]
      end

      def post_configuration
        Logging.logger.debug "post configuration"
      end

      def device_not_ready
        update_status :error, DEVICE_NOT_READY
        update_status :in_input, false
      end

      def device_ready
        update_status :error, nil
        update_status :model, @device.model
        update_status :version, @device.version
      end

      def input_event(event, data = nil)
        publish_event :input, event, data

        case event
        when :start
          update_status :in_input, true

        when :accept, :cancel
          update_status :in_input, false
        end
      end
    end
  end
end
