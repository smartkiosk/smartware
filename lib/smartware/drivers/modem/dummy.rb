# coding: utf-8
module Smartware
  module Driver
    module Modem

      class Dummy

        def initialize(port)
          @port = port
        end

        def model
          'Generic modem'
        end

        def error
          false
        end

        def signal_level
          res = %w(-55 -51 -57 -53).sample
          "#{res} dbm"
        end

        def ussd(code="*100#")
          "Сервис временно недоступен"
        end

      end

    end
  end
end

