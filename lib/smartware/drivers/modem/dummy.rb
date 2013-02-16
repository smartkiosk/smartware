# coding: utf-8
module Smartware
  module Driver
    module Modem

      class Dummy
        attr_accessor :account

        def initialize(config)

        end

        def model
          'Generic modem'
        end

        def version
          '8 Ultimate'
        end

        def error
          nil
        end

        def signal_level
          res = %w(-55 -51 -57 -53).sample
          "#{res} dbm"
        end

        def balance
          "Service is temporarily disabled"
        end

        def tick
          sleep 10
        end
      end

    end
  end
end

