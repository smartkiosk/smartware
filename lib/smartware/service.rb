module Smartware
  class Service
    attr_reader :config

    def initialize(config_file)
      @config = YAML.load File.read(config_file)
      @interfaces = []
    end

    def start
      EventMachine.epoll
      EventMachine.run do
        @interfaces = @config["interfaces"].map do |config|
          interface = Smartware::Interface.const_get(config['name']).new config

          DRb::DRbServer.new config["uri"], interface
        end

        unless @config["connection_timeout"].nil?
          Thread.new do
            begin
              monitor = ConnectionMonitor.new @config["connection_timeout"].to_i

              monitor.run
            rescue => e
              Smartware::Logging.logger.error "Exception in connection monitor thread: #{e}"
              e.backtrace.each { |line| Smartware::Logging.logger.error line }
            end
          end
        end
      end

    end

    def stop
      @interfaces.each &:stop_service

      EventMachine.stop_event_loop
    end

    def join
      @interfaces.each do |server|
        server.thread.join
      end
    end
  end
end

