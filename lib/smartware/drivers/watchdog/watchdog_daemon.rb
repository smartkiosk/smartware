module Smartware
  module Driver
    module Watchdog

      class WatchdogDaemon

        attr_reader :error

        def initialize(config)
          @error = nil
          @config = config
        end

        def model
          "watchdogd-controlled watchdog"
        end

        def version
          ""
        end

        def reboot_modem
          begin
            File.open(@config["pidfile"], "r") do |io|
              pid = io.read.to_i

              Process.kill :USR1, pid
            end

            @error = nil
          rescue => e
            Smartware::Logging.logger.warn "Watchdog communication error: #{e}"

            @error = Interface::Watchdog::WATCHDOG_NOT_AVAILABLE
          end
        end
      end
    end
  end
end
