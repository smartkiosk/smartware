# coding: utf-8
module Smartware
  module Driver
    module Modem

      class Dummy

        def initialize(config)

        end

        def model
          'Generic modem'
        end

        def version
          '8 Ultimate'
        end

        def error
          false
        end

        def signal_level
          res = %w(-55 -51 -57 -53).sample
          "#{res} dbm"
        end

        def balance
          "Сервис временно недоступен"
        end

        def tick
          sleep 10
        end
      end

    end
  end
end

