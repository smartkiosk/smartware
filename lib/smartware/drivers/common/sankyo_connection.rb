require "smartware/drivers/common/command_based_device"
require "digest/crc16_xmodem"

module Smartware
  class SankyoConnection < CommandBasedDevice
    class CommandResponse
      def initialize(response)
        @response = response
      end

      def positive?
        @response[0] == "P"
      end

      def negative?
        @response[0] != "P"
      end

      def response
        @response[1..-1]
      end
    end

    STX = 0xF2
    ACK = 0x06
    NAK = 0x15

    attr_accessor :initialize_device

    def initialize
      super

      @command_timer = nil
      @initialize_device = nil
      @ready_for_commands = false
      @state = :drop

      EventMachine.add_periodic_timer(10) { check_dsr! }
      EventMachine.next_tick { check_dsr! }
    end

    protected

    def check_dsr!
      if @io.dsr == 0
        @state = :drop
        kill_queue
      else
        was_ready, @ready_for_commands = @ready_for_commands, true

        if !was_ready
          @initialize_device.call
        end
      end
    end

    def remove_timeouts
      unless @command_timer.nil?
        EventMachine.cancel_timer @command_timer
        @command_timer = nil
      end
    end

    def install_timeouts(type = :sync)
      interval = nil
      case type
      when :sync
        interval = 0.3

      when :command
        interval = 20

      else
        raise "invalid timeout type: #{type.inspect}"
      end

      @command_timer = EventMachine.add_timer(interval) do
        @command_timer = nil
        retry_or_fail
        post_command unless @executing_command
      end
    end

    def max_retries
      8
    end

    def submit_command(*bytes)
      data = [ STX, bytes.length + 1 ].pack("Cn")
      data << "C"
      data << bytes.pack("C*")

      crc = Digest::CRC16XModem.new
      crc << data
      data << [ crc.checksum ].pack("n")

      @state = :sync
      send_data data
    end

    def complete(response)
      @state = :drop
      super
    end

    def handle_response
      until @buffer.empty?
        case @state
        when :drop
          @buffer.clear

        when :sync
          initial_byte = @buffer.slice!(0, 1).ord

          case initial_byte
          when ACK
            @state = :response
            remove_timeouts
            install_timeouts :command

          when NAK
            retry_or_fail
          end

        when :response
          break if @buffer.length < 5

          leading_byte, length = @buffer[0..2].unpack("Cn")
          if leading_byte != STX
            @buffer.slice! 0, 1
            next
          end

          full_length = 5 + length

          break if @buffer.length < full_length

          message = @buffer.slice! 0, full_length
          sum, = message.slice!(full_length - 2, 2).unpack("n")
          crc = Digest::CRC16XModem.new
          crc << message
          if sum == crc.checksum
            send_data ACK.chr
            complete CommandResponse.new(message[3..-1])
          else
            send_data NAK.chr
          end
        end
      end

      post_command
    end
  end
end