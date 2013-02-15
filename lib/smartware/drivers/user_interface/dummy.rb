require "base64"

module Smartware
  module Driver
    module UserInterface
      class Dummy

        SCREENSHOT = Base64.decode64("R0lGODlhAQABAIAAAAAAAP///yH5BAEAAAAALAAAAAABAAEAAAIBRAA7")

        def initialize(config)

        end

        def delete_calibration

        end

        def restart_ui

        end

        def screenshot
          SCREENSHOT
        end
      end
    end
  end
end
