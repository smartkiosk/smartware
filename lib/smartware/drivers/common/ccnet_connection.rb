require "smartware/drivers/common/command_based_device.rb"

module Smartware
  class CCNETConnection < CommandBasedDevice

    POLYNOMIAL = 0x8408

    attr_accessor :address

    def initialize
      super

      @address = 0
      @command_timer = nil
    end

    protected

    def remove_timeouts
      unless @command_timer.nil?
        EventMachine.cancel_timer @command_timer
        @command_timer = nil
      end
    end

    def install_timeouts
      @command_timer = EventMachine.add_timer(1) do
        @command_timer = nil
        retry_or_fail
        post_command unless @executing_command
      end
    end

    def max_retries
      8
    end

    def submit_command(command = nil, data = "")
      if command.kind_of? Array
        command, subcommand = command
      else
        subcommand = nil
      end

      if data.length <= 250
        if command.nil?
          frame = [ 0x02, @address, data.size + 5 ].pack("C*")
        elsif subcommand.nil?
          frame = [ 0x02, @address, data.size + 6, command ].pack("C*")
        else
          frame = [ 0x02, @address, data.size + 7, command, subcommand ].pack("C*")
        end
      else
        if command.nil?
          frame = [ 0x02, @address, 0, data.size + 7 ].pack("C3n")
        elsif subcommand.nil?
          frame = [ 0x02, @address, 0, command, data.size + 8 ].pack("C4n")
        else
          frame = [ 0x02, @address, 0, command, subcommand, data.size + 9 ].pack("C5n")
        end
      end

      frame << data
      frame << [ crc_for(frame) ].pack("v")

      send_data frame
    end

    def crc_for(msg)
      crc = 0

      msg.each_byte do |byte|
        crc ^= byte

        8.times do
          if (crc & 1) != 0
            crc >>= 1
            crc ^= POLYNOMIAL
          else
            crc >>= 1
          end
        end
      end

      crc
    end

    def handle_response
      while @buffer.size >= 5
        short_length = @buffer.getbyte(2)
        if short_length == 0
          break if @buffer.size < 7

          length, = @buffer.slice(3, 2).unpack("n")
        else
          length = short_length
        end

        break if @buffer.size < length

        message = @buffer.slice! 0, length
        crc, = message[-2..-1].unpack("v")
        expected_crc = crc_for(message[0..-3])

        if expected_crc != crc
          Logging.logger.warn "bad response CRC: #{expected_crc} expected, #{crc} got"

          retry_or_fail if @executing_command
          next
        end

        if message.getbyte(1) != @address
          Logging.logger.warn "unexpected address: #{@buffer.inspect}"

          next
        end

        if @executing_command
          # Acknowlege
          submit_command nil, "\x00"

          if short_length == 0
            complete message[5..-3]
          else
            complete message[3..-3]
          end
        else
          Logging.logger.warn "unexpected message: #{@buffer.inspect}"
        end
      end

      post_command unless @executing_command
    end
  end
end
