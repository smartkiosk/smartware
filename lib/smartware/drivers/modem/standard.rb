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
          @sp.read_timeout = 100
        end

        def error
          @error ||= false
        end

        def model
          res = send 'ATI'
          res.shift
          res.pop
          res.join(' ')
        rescue
          @error = ERRORS["20"]
        end

        #
        # Returns signal level in dbm
        #
        def signal_level
          res = send 'AT+CSQ'
          value = res[1].gsub("+CSQ: ",'').split(',')[0].to_i
          "#{(-113 + value * 2)} dbm"
        rescue
          @error = ERRORS["21"]
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
          res = self.send "AT+CUSD=1,\"#{code}\",15"
          ussd_body = res[1].split(",")[1].gsub('"','') # Parse USSD message body
          ussd_body.scan(/\w{4}/).map{|i| [i.hex].pack("U") }.join.strip # Encode USSD message from broken ucs2 to utf-8
        rescue
          @error = ERRORS["10"]
          return false
        end

        def send(cmd)
          read_port @sp # Port clear

          @sp.write "AT\r\n"
          check_ability = read_port @sp
          return ERRORS["-1"] unless check_ability == ["AT", "OK"]

          @sp.write "#{ cmd }\r\n"
          answer = read_port @sp
        end

        def read_port(io, read_timeout = 0.25)
          return ERRORS["-1"] unless io
          answer = ''
          while IO.select [io], [], [], read_timeout
            chr = io.getc.chr
            answer << chr
          end
          answer.split(/[\r\n]+/)
        end
      end

    end
  end
end
