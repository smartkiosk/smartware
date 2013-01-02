# coding: utf-8
module Smartware
  module Driver
    module Modem

      class Dummy

        def initialize(port)
          @port = port
        end

        def model
          'Dummy modem v1.0'
        end

        def error
          false
        end

        def signal_level
          "-#{rand(90)*10+rand(9)} dbm"
        end

        #
        # Method send ussd to operator and return only valid answer body
        # Don`t call with method synchronously from app, method waits USSD answer 3 sec,
        # Use some scheduler and buffer for balance value
        #
        def ussd(code="*100#")
          "#{rand(90)*100+rand(9)} " + %w(руб. dollars тэньге).sample
        end

      end

    end
  end
end

