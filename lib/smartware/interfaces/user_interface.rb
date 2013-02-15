module Smartware
  module Interface
    class UserInterface < Interface

      def initialize(config, service)
        super

        update_status :error, nil
        update_status :model, ''
        update_status :version, ''
        update_status :screenshot_pending, false

        @screenshot_data = nil
      end

      def delete_calibration
        Logging.logger.info "Deleting calibration data"
        @device.delete_calibration
      end

      def restart_ui
        Logging.logger.info "Restarting user interface"
        @device.restart_ui
      end

      def request_screenshot
        Logging.logger.info "Requested screenshot"

        EventMachine.defer @device.method(:screenshot), ->(data) do
          @screenshot_data = data
          update_status :screenshot_pending, true
        end

        nil
      end

      def retrieve_screenshot
        data = @screenshot_data
        @screenshot_data = nil
        update_status :screenshot_pending, false

        data
      end
    end
  end
end
