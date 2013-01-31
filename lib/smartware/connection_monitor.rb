module Smartware
  class ConnectionMonitor
    def initialize(timeout, service)
      @timeout = timeout
      @service = service
      @timer = nil
      @queue = @service.amqp_channel.queue '', exclusive: true
      @queue.bind @service.amqp_status, routing_key: 'modem.error'
      @queue.subscribe &method(:message)
    end

    def run
      @service.amqp_general.publish "update"
    end

    private

    def message(hdr, message)
      error, = JSON.load(message)

      if error.nil? && !@timer.nil?
        EventMachine.cancel_timer @timer
      elsif !error.nil? && @timer.nil?
        @timer = EventMachine.add_timer @timeout, method(:modem_failure)
      end
    end

    def modem_failure
      @timer = nil

      Logging.logger.warn "Rebooting modem."

      @service.amqp_commands.publish JSON.dump([ "reboot_modem" ]),
          routing_key: 'watchdog'
    end
  end
end
