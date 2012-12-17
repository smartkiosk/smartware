# coding: utf-8
require 'serialport'

module Smartware
  module Driver
    module Modem

      class Standart

        def initialize(port)
          # @port Class variable needs for ussd request
          @port = port
          @sp = SerialPort.new(@port, 115200, 8, 1, SerialPort::NONE)
        end

        def error
          false
        end

        def model
          res = send 'ATI' rescue -1
          return -1 unless res.last == "OK"

          res.shift
          res.pop
          res.join(' ')
        rescue
          -1
        end

        #
        # Returns signal level in dbm
        #
        def signal_level
          res = send 'AT+CSQ'
          return -1 if res.last != "OK"
          value = res[1].gsub("+CSQ: ",'').split(',')[0].to_i
          "#{(-113 + value * 2)} dbm"
        rescue
          -1
        end

        #
        # Method send ussd to operator and return only valid answer body
        # Don`t call with method synchronously from app, method waits USSD answer 3 sec,
        # Use some scheduler and buffer for balance value
        #
        def ussd(code="*100#")
          port = SerialPort.new(@port, 115200, 8, 1, SerialPort::NONE)
          port.read_timeout = 3000
          port.write "AT+CUSD=1,\"#{code}\",15\r\n"
          ussd_body = port.read.split(/[\r\n]+/).last.split(",")[1].gsub('"','') # Get only USSD message body
          port.close
          ussd_body.scan(/\w{4}/).map{|i| [i.hex].pack("U") }.join # Encode USSD message from broken ucs2 to utf-8
        rescue
          -1
        end

        private
          def send cmd
            @sp.write "#{ cmd }\r\n"
            answer = ''
            while IO.select [@sp], [], [], 0.25
              chr = @sp.getc.chr
              answer << chr
            end
            answer.split(/[\r\n]+/)
          end

      end

    end
  end
end
