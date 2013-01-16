module Smartware
  module Driver
    module Watchdog

      class Dummy

        def initialize(config)

        end

        def model
          "Dummy watchdog"
        end

        def version
          ""
        end

        def reboot_modem

        end

        def error
          nil
        end
      end
    end
  end
end
