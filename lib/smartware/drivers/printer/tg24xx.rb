# coding: utf-8
require 'serialport'

module Smartware
  module Driver
    module Printer

      class TG24XX

        def initialize(port)
          @sp = SerialPort.new(port, 115200, 8, 1, SerialPort::NONE)
          @sp.read_timeout = 100
        end

        def error
          res = send "\x1Dr1"
          return "1" unless res        # No answer
          return "" if res == "0"      # No error
          return "2" if res == "f"     # Paper not present
          return "3" if res == "3"     # Paper near end
        rescue
          -1
        end

        def model
          model_code  = send "\x1DI1"
          rom_version = send "\x1DI3", false
          model_name  = case model_code
                          when "a7" then 'Custom TG2460H'
                          when "a8" then 'Custom TG2480H'
                          when "ac" then 'Custom TL80'
                          when "ad" then 'Custom TL60'
                          else 'Unknown printer'
                        end
          "#{model_name}, ROM v#{rom_version}"
        rescue
          -1
        end

        private
          def send(message, parse_answer = true)
            @sp.write message
            ans = @sp.gets
            if ans
              parse_answer ? res = ans.unpack("C*").map{|e| e.to_s(16) } : res = ans
            else
              res = nil
            end
            res.is_a?(Array) ? res[0] : res
          end

      end

    end
  end
end

