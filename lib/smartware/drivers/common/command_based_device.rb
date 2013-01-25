module Smartware
  class CommandBasedDevice < EventMachine::Connection
    def initialize
      @ready_for_commands = true
      @executing_command = false
      @retries = nil
      @command = nil
      @completion_proc = nil
      @buffer = ""

      @command_queue = []
      @command_mutex = Mutex.new
    end

    def receive_data(data)
      @buffer << data

      handle_response
    end

    def command(*args, &block)
      if !block_given?
        queue = Queue.new
        command(*args) do |resp|
          queue.push resp
        end
        queue.pop
      else
        @command_mutex.synchronize do
          @command_queue.push [ args, block ]
        end

        EventMachine.schedule method(:post_command)
      end
    end

    protected

    def ready?
      @ready_for_commands && !@executing_command
    end

    def post_command
      executing_command, command = @command_mutex.synchronize do
        if ready?
          [ @command_queue.any?, @command_queue.first ]
        else
          [ false, nil ]
        end
      end

      if executing_command
        @executing_command = executing_command
        install_timeouts
        @retries = max_retries
        command, = @command_mutex.synchronize { @command_queue.first }
        submit_command *command
      end
    end

    def kill_queue
      blocks = nil

      @command_mutex.synchronize do
        blocks = @command_queue.map { |command, block| block }
        @command_queue.clear

        @ready_for_commands = false
      end

      blocks.each do |block|
        block.call nil
      end
    end

    def retry_or_fail
      if @retries == 0
        complete nil
      else
        @retries -= 1
        command, = @command_mutex.synchronize { @command_queue.first }
        remove_timeouts
        install_timeouts
        submit_command *command
      end
    end

    def complete(data)
      command, proc = @command_mutex.synchronize { @command_queue.shift }
      remove_timeouts
      @executing_command = false

      begin
        proc.call data
      rescue => e
        Logging.logger.error "Error in completion handler: #{e}"
        e.backtrace.each { |line| Logging.logger.error line }
      end
    end
  end
end
