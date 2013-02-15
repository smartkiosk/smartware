require "smartware/drivers/common/szzt_connection"
require "openssl"

module Smartware
  module Driver
    module PinPad
      class ZT588

        class ZT588Error < Interface::PinPad::PinPadError; end

        # Commands
        LOAD_PLAIN_KEY      = '1'
        LOAD_ENCRYPTED_KEY  = '2'
        USER_INFORMATION    = '3'
        LOAD_SCANCODE_TABLE = '4'
        CONTROL             = '5'
        START_PIN_INPUT     = '6'
        GET_PIN_VALUE       = '7'
        AUTH = ':'

        # Control commands and values
        MISC                = '0'
          RESET             = '0'
          WIPE              = '1'
          DISABLE_INPUT     = '2'
          ENABLE_INPUT      = '3'
          DISABLE_SOUND     = '4'
          ENABLE_SOUND      = '5'
          BEEP              = '='
        SET_INPUT_TIME_LIMIT = '2'
        SET_PIN_MASK         = '3'
        SET_MIN_LENGTH       = '4'
        SET_MAX_LENGTH       = '5'
        SET_COMMUNICATION    = '6'
          SET_BROKEN_HEX     = '0'
          SET_HEX            = '7'
          SET_1200           = 'H'
          SET_2400           = 'I'
          SET_4800           = 'J'
          SET_9600           = 'K'
          SET_19200          = 'L'
          SET_38400          = 'M'
          SET_57600          = 'N'
          SET_115200         = 'O'
        SET_BEEP_TIME        = '8'

        # Authentication commands
        AUTH_GET_CHALLENGE = 0xA0
        AUTH_WITH_TMK = 0x90
        AUTH_WITH_IMK = 0x91

        # Settings layout data
        REVERSE_BAUD_TABLE = {
          48 => 1200,
          49 => 2400,
          50 => 4800,
          51 => 9600,
          52 => 19200,
          53 => 38400,
          54 => 57600,
          55 => 115200
        }

        # Authentication data
        UID = "0000000000000000"

        # Keys
        KEY_TMK = 0x00
        KEY_IMK = 0x80

        # Key types, etc
        KEY_TYPE_IMK  = 1
        KEY_TYPE_TMK  = 2
        KEY_TYPE_TPK  = 3

        KEY_TYPE_TAK  = 5
        KEY_TYPE_TDK  = 6
        KEY_TYPE_TDEK = 7
        KEY_TYPE_TDDK = 8
        KEY_TYPE_TDSK = 9

        KEY_LENGTH_SINGLE = 0
        KEY_LENGTH_DOUBLE = 1
        KEY_LENGTH_TRIPLE = 2

        PIN_TYPE_MAP = {
          Smartware::Interface::PinPad::ASCII     => '@',
          Smartware::Interface::PinPad::ISO9564_0 => ' ',
          Smartware::Interface::PinPad::ISO9564_1 => '!',
          Smartware::Interface::PinPad::ISO9564_3 => '#',
          Smartware::Interface::PinPad::IBM3624   => '0'
        }

        DEFAULT_CONFIG = {
          "sound"              => true,
          "input_time_limit"   => 30,
          "minimum_pin_length" => 1,
          "maximum_pin_length" => 16,
          "beep_time"          => 0.1
        }

        # ZT88 keyboard matrix:
        # [1 ] [2 ] [3 ] [cancel]
        # [4 ] [5 ] [6 ] [clear ]
        # [7 ] [8 ] [9 ] [      ]
        # [. ] [0 ] [00] [enter ]
        # [A ] [C ] [E ] [G     ]
        # [B ] [D ] [F ] [H     ]
        #
        # A-D - left-side application keys,
        # E-H - right-side application keys.
        SCANCODES = %W{
          1 2 3 \e
          4 5 6 \b
          7 8 9 \a
          . 0 # \r
          A C E G
          B D F H
        }.join

        ERRORS = {
          0xE0 => "Low battery",
          0xE1 => "IMK required",
          0xE2 => "TMK required",
          0xE3 => "Unexpected key size",
          0xE4 => "Key not found",
          0xE5 => "Key not found or not compatible",
          0xE6 => "Key parity check failed",
          0xE7 => "Key is not valid",
          0xE8 => "Unexpected command length",
          0xE9 => "Incorrect data",
          0xEB => "Incorrect parameter",
          0xEC => "Authorization required",
          0xED => "Authorization temporary locked",
          0xEE => "Input timed out",
          0xEF => "General error"
        }

        attr_accessor :imk_source, :post_configuration, :device_ready
        attr_accessor :device_not_ready, :input_event
        attr_reader :user_data, :model, :version

        def initialize(config)
          @config = DEFAULT_CONFIG.merge(config)
          @plain_input = false
          @auto_stop = nil

          @port = SerialPort.new(config["port"], 9600, 8, 1, SerialPort::NONE)
          @port.flow_control = SerialPort::HARD

          @connection = EventMachine.attach @port, SZZTConnection
          @connection.baud_test_command = '3'
          @connection.baud_switch_command = ->(baud) {
            sprintf('56%d', baud + 41)
          }
          @connection.dsr_fall = method :dsr_fall
          @connection.initialize_device = method :initialize_device
          @connection.handle_keypad = method :handle_keypad

          @imk_source = nil
          @post_configuration = nil
          @device_ready = nil
          @device_not_ready = nil
          @input_event = nil
        end

        def user_data=(data)
          safe_command USER_INFORMATION, data
          info = query_user_information
          @user_data = info[:user_info]
        end

=begin unsafe - enable at your own risk
        def wipe
          control MISC, WIPE
          sleep 3
          initialize_device true
        end
=end

        def restart
          control MISC, RESET
          sleep 3
          initialize_device
        end

        def start_input(mode, options = {})
          case mode
          when Interface::PinPad::INPUT_PLAINTEXT
            @plain_input = true
            @auto_stop = nil
            control MISC, ENABLE_INPUT

          when Interface::PinPad::INPUT_PIN
            tpk = 0x40 + 8 * options[:key_set]
            @plain_input = false
            @auto_stop = options[:length]

            start_pin_input tpk, options[:format], 0, options[:length],
                            options[:pan]

          else
            raise ZT588Error, "unsupported input mode: #{mode}"
          end

          @input_event.call :start
        end

        def stop_input
          do_stop_input
          @input_event.call :cancel
        end

        def start_pin_input(key, format, hint_code, length, pan)
          raise "unsupported PIN block format" unless PIN_TYPE_MAP.include? format

          safe_command(START_PIN_INPUT,
                       sprintf("%02X%c%d%02d%s",
                               key,
                               PIN_TYPE_MAP[format],
                               hint_code,
                               length,
                               pan))
        end

        def load_working_keys(set, tpk_under_tmk)
          raise "unsupported key set" unless (0..7).include? set

          tpk = 0x40 + 8 * set
          tpk_verify = load_encrypted_key tpk, KEY_TMK, KEY_TYPE_TPK, nil,
                                          tpk_under_tmk

          return tpk_verify
        end

        def get_pin
          response = safe_command GET_PIN_VALUE

          p response

          [
            response.slice(1, 2).to_i, # Track
            response.slice(3, 2).to_i, # Length
            bin(response[5..-1])       # Block
          ]
        end

        private

        def calculate_response(challenge, key)
          cipher = OpenSSL::Cipher.new('DES-ECB')
          cipher.encrypt
          cipher.padding = 0
          cipher.key = key
          cipher.update(challenge) + cipher.final
        end

        def auth(command, data)
          response = safe_command AUTH, sprintf("%02X", command), hex(data)
          bin response[1..-1]
        end

        def probe_length(data)
          case data.length
          when 8
            KEY_LENGTH_SINGLE

          when 16
            KEY_LENGTH_DOUBLE

          when 24
            KEY_LENGTH_TRIPLE

          else
            raise "unsupported key length: #{data.bytes}"
          end
        end

        def erase_key(key)
          safe_command LOAD_ENCRYPTED_KEY, sprintf("%02X%02X%d%d", 0, key, 0, 0)
          nil
        end

        def load_encrypted_key(key, under, type, length, data)
          length = probe_length(data) if length.nil?
          response = safe_command(LOAD_ENCRYPTED_KEY,
                                  sprintf("%02X%02X%d%d", under, key, type, length + 1),
                                  hex(data))
          bin response[1..-1]
        end

        def load_plain_key(key_index, key_type, length, data)
          length = probe_length(data) if length.nil?
          response = safe_command(LOAD_PLAIN_KEY,
                                  sprintf("%02X%u%u", key_index, key_type, length),
                                  hex(data))

          verify = bin response[1..-1]

          zeroes = "\x00" * data.length

          cipher = OpenSSL::Cipher.new('DES-ECB')
          cipher.reset
          cipher.encrypt
          cipher.padding = 0
          cipher.key = data
          check = cipher.update(zeroes) + cipher.final

          if check.slice(0, verify.length) != verify
            raise ZT588Error, "Plaintext key validation failed"
          end

          verify
        end

        def parse_settings(data)
          bytes = data.unpack("C*")

          {
            blank: bytes[0] & 0x01 == 0x01,
            input: bytes[0] & 0x02 == 0x02,
            sound: bytes[0] & 0x04 == 0x04,

            input_time: bytes[2],
            pin_mask:   bytes[3].chr,
            min_length: bytes[4],
            max_length: bytes[5],
            baud:       REVERSE_BAUD_TABLE[bytes[6]],
            broken_hex: bytes[7].chr == SET_BROKEN_HEX,
            beep_time:  bytes[8] / 100.0,

            raw: bytes
          }
        end

        def query_user_information
          info = safe_command USER_INFORMATION

          parts = info.unpack("xa50a48a20a8A6A3A3a4a4")

          {
            user_info: parts[0],
            scancodes: bin(parts[1]),
            settings: parse_settings(bin(parts[2])),
            function_code: parts[3],
            model: parts[4],
            hardware_version: parts[5],
            software_version: parts[6],
            production_date: parts[7],
            serial: parts[8],
          }
        end

        def dsr_fall
          @device_not_ready.call
        end

        def initialize_device(reload = false)
          Logging.logger.debug "ZT588: initializing"

          control SET_COMMUNICATION, SET_HEX

          info = query_user_information

          @model = info[:model]
          @version = "#{info[:hardware_version]}-#{info[:software_version]}"
          @user_data = info[:user_info]

          Logging.logger.debug "ZT588: It's #{@model}-#{@version}"
          Logging.logger.debug "ZT588: Production date: #{info[:production_date]}, serial number: #{info[:serial]}"

          safe_command LOAD_SCANCODE_TABLE, hex(SCANCODES)
          control MISC,                     @config["sound"] ? ENABLE_SOUND : DISABLE_SOUND
          control SET_INPUT_TIME_LIMIT,     @config["input_time_limit"].chr
          control SET_PIN_MASK,             "\xFF"
          control SET_MIN_LENGTH,           @config["minimum_pin_length"].chr
          control SET_MAX_LENGTH,           @config["maximum_pin_length"].chr
          control SET_BEEP_TIME,            (@config["beep_time"] * 100).round.chr

          if info[:settings][:input]
            control MISC, DISABLE_INPUT
          end

          if !reload
            if info[:settings][:blank]
              Logging.logger.warn "ZT588: IMK not loaded, pinpad unoperational"
=begin unsafe - enable at your own risk
              imk, tmk = @imk_source.call

              return if imk.nil?

              wipe
              load_plain_key KEY_IMK, KEY_TYPE_IMK, KEY_LENGTH_TRIPLE, imk
              imk.slice! 16

              challenge = auth AUTH_GET_CHALLENGE, "0000000000000000"
              response  = calculate_response challenge, imk.slice(0, 16)
              check     = calculate_response response, imk.slice(0, 16)
              verify    = auth AUTH_WITH_IMK, response
              raise ZT588Error, "verification failed" if check != verify

              # it's likely that TMK is actually IMK, and IMK is something else
              load_plain_key KEY_TMK, KEY_TYPE_IMK, KEY_LENGTH_DOUBLE, tmk
              @post_configuration.call

              restart
=end
            else
              [0x10, 0x20, 0x30].each do |key|
                p key
                begin
                  random    = auth AUTH_GET_CHALLENGE, "0000000000000000"
                  challenge = auth key, random
                  response  = calculate_response challenge, UID
                  check     = calculate_response response, UID
                  verify    = auth AUTH_WITH_TMK, response
                  raise ZT588Error, "verification failed" if check != verify
                  Logging.logger.debug "ZT588: authenticated"

                  break
                rescue => e
                  p e
                end
              end

              @device_ready.call
            end
          end

        rescue => e
          Logging.logger.error "initialize_device failed: #{e}"
          e.backtrace.each { |line| Logging.logger.error line }
        end

        def do_stop_input
          @plain_input = false
          @auto_stop = nil
          control MISC, DISABLE_INPUT
        end

        def do_auto_stop(chars = 1)
          unless @auto_stop.nil?
            @auto_stop -= chars
            if @auto_stop <= 0
              @plain_input = false
              @auto_stop = nil
              @input_event.call :accept
            end
          end
        end

        def handle_keypad(char)
          case char
          when "\e", "\x80"
            do_stop_input if @plain_input
            @input_event.call :cancel

          when "\b"
            @input_event.call :backspace

          when "\r"
            do_stop_input if @plain_input
            @input_event.call :accept

          when "\a", 'A'..'H'
            # unlabeled button and application buttons

          when '#'
            @input_event.call :input, '0'
            @input_event.call :input, '0'
            do_auto_stop 2

          else
            @input_event.call :input, char
            do_auto_stop 1
          end

        end

        def control(parameter, value)
          safe_command CONTROL, parameter, hex(value)
        end

        def safe_command(*parts)
          response = @connection.command parts.join
          raise ZT588Error, "Communication error" if response.nil?

          code = response.getbyte 0
          if code >= 0xE0 && code <= 0xEF
            description = ERRORS[code] || "unknown error #{code.to_s 16}"
            raise ZT588Error, description
          end

          response
        end

        def hex(binary)
          hex, = binary.unpack("H*")
          hex.upcase!
          hex
        end

        def bin(hex)
          [ hex ].pack("H*")
        end
      end
    end
  end
end
