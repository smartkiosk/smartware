# coding: utf-8
#
# CCNET protocol driver for CashCode bill validator
#
require 'serialport'

module Smartware
  module Driver
    module CashAcceptor

      class CCNET

        RESET                  = 0x30
        GET_STATUS             = 0x31
        SET_SECURITY           = 0x32
        POLL                   = 0x33
        ENABLE_BILL_TYPES      = 0x34
        STACK                  = 0x35
        RETURN                 = 0x36
        IDENTIFICATION         = 0x37
        HOLD                   = 0x38
        SET_BARCODE_PARAMETERS = 0x39
        EXTRACT_BARCODE_DATA   = 0x3A
        GET_BILL_TABLE         = 0x41
        GET_CRC32_OF_THE_CODE  = 0x51
        DOWNLOAD               = 0x50
        REQUEST_STATISTICS     = 0x60
        ACK                    = 0x00
        DISPENCE               = 0x3C

        STATUSES = {
            "10" => "10", # 'Power up',
            "11" => "11", # 'Power Up with Bill in Validator',
            "12" => "12", # 'Power Up with Bill in Stacker',
            "13" => "13", # 'Initialize',
            "14" => "14", # 'Idling',
            "15" => "15", # 'Accepting',
            "17" => "16", # 'Stacking',
            "18" => "17", # 'Returning',
            "19" => "18", # 'Unit Disabled',
            "1a" => "19", # 'Holding',
            "1b" => "20", # 'Device Busy',
            "1c" => "21", # 'Rejecting',
            "82" => "22"  # 'Bill returned'
        }

        ERRORS = {
            "41" => "23", # 'Drop Cassette Full',
            "42" => "24", # 'Drop Cassette out of position. The Bill Validator has detected the drop cassette to be open or removed.',
            "43" => "25", # 'Validator Jammed. A bill(s) has jammed in the acceptance path.',
            "44" => "26", # 'Drop Cassette Jammed. A bill has jammed in drop cassette.',
            "45" => "27", # 'Cheated. Intentions of the user to deceive the Bill Validator are detected',
            "46" => "28", # 'Pause. Bill Validator stops motion of the second bill until the second bill is removed.',
            "47" => "29", # 'Bill validator failure',
            "50" => "30", # 'Stack Motor Failure',
            "51" => "31", # 'Transport Motor Speed Failure',
            "52" => "32", # 'Transport Motor Failure',
            "53" => "33", # 'Aligning Motor Failure',
            "54" => "34", # 'Initial Cassette Status Failure',
            "55" => "35", # 'Optic Canal Failure',
            "56" => "36", # 'Magnetic Canal Failure',
            "5f" => "37"  # 'Capacitance Canal Failure'
        }

        NOMINALS = { "2" => 10, "3" => 50, "4" => 100, "5" => 500, "6" => 1000, "7" => 5000 }

        def initialize(port)
          @port = port
        end

        def cassette?
          return false if error == "24"
          true
        end

        def model
          if answer = send([IDENTIFICATION], false)
            answer = answer[2..answer.length]
            return "#{answer[0..15]} #{answer[16..27]} #{answer[28..34].unpack("C*")}"
          else
            return "Unknown device answer"
          end
        rescue
          -1
        end

        def version
          # TODO: implement this
          "not implemented"
        end

        def error
          res = poll
          ack
          return false if res != nil and CCNET::STATUSES.keys.include?(res[3])
          return false if res == nil

          result = check_error(res)
        rescue
          -1
        end

        def current_banknote
          poll
          ack
          hold
          res = poll
          ack

          result = check_error(res)
          if res != nil and res[2] == "7" and res[3] == "80" and CCNET::NOMINALS.keys.include?(res[4]) # has money?
            result =  CCNET::NOMINALS[res[4]]
          end
          result
        end

        def get_status
          send([GET_STATUS])
        end

        def reset
          send([RESET])
        end

        def ack
          send([ACK])
        end

        def stack
          send([STACK])
        end

        def return
          send([RETURN])
        end

        def hold
          send([])
        end

        def poll
          send([POLL])
        end

        def accept
          send([ENABLE_BILL_TYPES,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF])
        end

        def cancel_accept
          send([ENABLE_BILL_TYPES,0x00,0x00,0x00,0x00,0x00,0x00])
          get_status
        end

        private
          def check_error(res)
            if CCNET::ERRORS.keys.include? res[3]
              res[3] == "47" ? CCNET::ERRORS[res[4]] : CCNET::ERRORS[res[3]] # More details for 47 error
            else
              false
            end
          end

          def crc_for(msg)
            polynom = 0x8408.to_i
            msg  = msg.collect{|o| o.to_i}
            res = 0
            tmpcrc = 0
            0.upto(msg.length-1){|i|
              tmpcrc = res ^ msg[i]
              0.upto(7){
                if tmpcrc & 1 != 0
                  tmpcrc = tmpcrc >> 1
                  tmpcrc = tmpcrc ^ polynom
                else
                  tmpcrc = tmpcrc >> 1
                end
              }
              res = tmpcrc
            }
            crc = tmpcrc
            crc = ("%02x" % crc).rjust(4,"0")
            crc = [Integer("0x"+crc[2..3]), Integer("0x"+crc[0..1])]
          end

          def send(msg, parse_answer = true)
            sp = SerialPort.new(@port, 9600, 8, 1, SerialPort::NONE)
            sp.read_timeout = 100
            message = [0x02, 0x03, 5 + msg.length]
            message += msg
            crc = crc_for(message)
            message += crc
            message = message.pack("C*")
            sp.write message
            ans = sp.gets
            if ans
              parse_answer ? res = ans.unpack("C*").map{|e| e.to_s(16) } : res = ans
            else
              res = nil
            end
            sp.close
            res
          end
      end

    end
  end
end