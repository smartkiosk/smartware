require "smartware/drivers/common/command_based_device"

module Smartware
  class SZZTConnection < CommandBasedDevice
    DESIRED_BAUD = 7
    BAUD_TABLE = [ 1200, 2400, 4800, 9600, 19200, 38400, 57600, 115200 ]

    attr_accessor :baud_test_command, :baud_switch_command, :initialize_device
    attr_accessor :handle_keypad, :dsr_fall

    def initialize
      super

      @ready_for_commands = false

      @command_timer = nil
      @probing_baud = false
      @baud_index = nil
      @baud_test_command = nil
      @baud_switch_command = nil
      @initialize_device = nil
      @handle_keypad = nil
      @dsr_fall = nil

      EventMachine.add_periodic_timer(1) { check_dsr! }
      EventMachine.next_tick { check_dsr! }
    end

    protected

    def check_dsr!
      if @io.dsr == 0
        if @ready_for_commands
          Logging.logger.debug "SZZT: DSR low detected"

          @state = :drop
          kill_queue

          @dsr_fall.call
        end
      else
        was_ready, @ready_for_commands = @ready_for_commands, true

        if !was_ready
          @probing_baud = true
          @baud_index = -1
          Logging.logger.debug "SZZT: starting baud probe"
          try_next_baud
        end
      end
    end

    def try_next_baud
      @baud_index = BAUD_TABLE.length - 1 if @baud_index == -1
      @io.baud = BAUD_TABLE[@baud_index]

      Logging.logger.debug "SZZT: trying baud #{@io.baud}"
      command(@baud_test_command) do |resp|
        if resp.nil?
          @baud_index -= 1
          try_next_baud
        else
          Logging.logger.debug "SZZT: found baud rate: #{BAUD_TABLE[@baud_index]}"

          if @baud_index != DESIRED_BAUD
            Logging.logger.debug "SZZT: changing baud rate: #{BAUD_TABLE[DESIRED_BAUD]}"

            cmd = @baud_switch_command.call(DESIRED_BAUD)
            command(cmd) do |resp|
              EventMachine.add_timer(0.25) do
                Logging.logger.debug "SZZT: checking baud"
                @baud_index = DESIRED_BAUD
                try_next_baud
              end
            end
          else
            Logging.logger.debug "SZZT: probe completed"
            @probing_baud = false

            EventMachine.defer @initialize_device
          end
        end
      end
    end

    def remove_timeouts
      unless @command_timer.nil?
        EventMachine.cancel_timer @command_timer
        @command_timer = nil
      end
    end


    def install_timeouts
      if @probing_baud
        interval = 0.25
      else
        interval = 1
      end

      @command_timer = EventMachine.add_timer(interval) do
        @command_timer = nil
        retry_or_fail
        post_command unless @executing_command
      end
    end

    def max_retries
      if @probing_baud
        0
      else
        4
      end
    end

    def calculate_crc(string)
      string.bytes.reduce 0, :^
    end

    def submit_command(text)
      command = sprintf "%03u%s\x03", text.length, text
      checksum = calculate_crc command

      send_data sprintf("\x02%s%02X", command, checksum)
    end

    def keypad(char)
      begin
        EventMachine.defer ->() do
          @handle_keypad.call char
        end
      rescue => e
        Logging.logger.error "handle_keypad failed: #{e}"
        e.backtrace.each { |line| Logging.logger.error line }
      end
    end

    def handle_response
      until @buffer.empty?
        sync_index = @buffer.index "\x02"

        if sync_index != 0
          if sync_index.nil?
            presses = @buffer
            @buffer = ""
          else
            presses = @buffer.slice! 0, sync_index
          end

          presses.each_char &method(:keypad)
        end

        break if sync_index.nil? || @buffer.length < 6

        len = @buffer[1..3].to_i
        full_length = 7 + len
        break if @buffer.length < full_length

        response = @buffer.slice! 0, full_length
        crc = calculate_crc response[1...full_length - 2]
        if response[-3] != "\x03"
          retry_or_fail

          next
        end

        if response[-2..-1].to_i(16) != crc
          retry_or_fail

          next

        end

        if @executing_command
          complete response[4..-4]
        else
          Logging.logger.warn "SZZT: unexpected frame: #{response[4..-4].inspect}"
        end
      end

      post_command
    end
  end
end
