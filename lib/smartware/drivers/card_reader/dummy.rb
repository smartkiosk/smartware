module Smartware
  module Driver
    module CardReader
      class Dummy
        def initialize(config)
          @accepting = false
          @state = nil
        end

        def model
          "Dummy card reader"
        end

        def version
          ""
        end

        def ready?
          true
        end

        def accepting?
          @accepting
        end

        def accepting=(accepting)
          @state = :accepting if accepting
          @accepting = accepting
        end

        def eject
          @state = :eject

          self
        end

        def capture
          @state = :eject
          self
        end

        def status
          case @state
          when nil
            :ready

          when :accepting
            @state = :inserted
            :card_at_gate

          when :inserted
            :card_inserted

          when :eject
            @state = nil
            :card_at_gate
          end
        end

        def read_magstrip
          [
            "B4154000000000000^IVANOV/IVAN^1501101000",
            "4154000000000000=1501101000",
            nil,
            nil
          ]
        end
      end
    end
  end
end
