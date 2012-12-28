# coding: utf-8
require 'serialport'

module Smartware
  module Driver
    module Modem

      class Standard

        ERRORS = {
            "-1" => -1, # invalid device answer
            "10" => 10, # invalid ussd answer
            "11" => 11, # invalid ussd answer size
            "12" => 12, # invalid ussd body answer size
            "20" => 20, # invalid modem model
            "21" => 21, # invalid modem signal level
        }

        def initialize(port)
          @sp = SerialPort.new(port, 115200, 8, 1, SerialPort::NONE)
        end

        def error
          false
        end

        def model
          res = send 'ATI'
          res.shift
          res.pop
          res.join(' ')
        rescue
          ERRORS["20"]
        end

        #
        # Returns signal level in dbm
        #
        def signal_level
          res = send 'AT+CSQ'
          value = res[1].gsub("+CSQ: ",'').split(',')[0].to_i
          "#{(-113 + value * 2)} dbm"
        rescue
          ERRORS["21"]
        end

        #
        # Method send ussd to operator and return only valid answer body
        # Returns modem balance by default, it works for MTS and Megafon, use *102# for Beeline
        # Do not call with method synchronously from app, method waits USSD answer some time,
        # Use some scheduler and buffer for balance value
        #
        # Valid ussd answer sample: ["", "+CUSD: 2,\"003100310035002C003000300440002E00320031002E00330031002004310430043B002E0020\",72", "OK"]
        #
        def ussd(code="*100#")
          res = self.send "AT+CUSD=1,\"#{code}\",15\r\n"
          return ERRORS["11"] if res.size < 3

          ussd_body = res[1].split(",")[1].gsub('"','') # Parse USSD message body
          result = ussd_body.scan(/\w{4}/).map{|i| [i.hex].pack("U") }.join # Encode USSD message from broken ucs2 to utf-8
          port.close
          result
        rescue
          ERRORS["10"]
        end

        def send(cmd, read_timeout = 0.25)
          @sp.write "#{ cmd }\r\n"
          answer = ''
          while IO.select [@sp], [], [], read_timeout
            chr = @sp.getc.chr
            answer << chr
          end
          res = answer.split(/[\r\n]+/)
          return ERRORS["-1"] unless res.last == "OK"
          res
        end
      end

    end
  end
end
