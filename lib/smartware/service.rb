module Smartware
  class Service
    attr_reader :config

    def initialize(config_file)
      @config = YAML.load File.read(config_file)
      @interfaces = []
      @devices = []
    end

    def start
      EventMachine.epoll
      EventMachine.run do
        @event_channel = EventMachine::Channel.new
        @event_channel.subscribe do |(key, args)|
          @pubsub.publish_event key, *args
        end

        @pubsub = PubSubServer.new "localhost", (@config["pubsub_port"] || 6100)
        @pubsub.repush = ->(connection) do
          @devices.each do |device|
            device.repush_events connection
          end
        end

        @config["interfaces"].each do |config|
          interface = Smartware::Interface.const_get(config['name']).new config, self
          @devices << interface

          if config.include? "uri"
            @interfaces << DRb::DRbServer.new(config["uri"], interface)
          end
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

    def publish_event(key, *args)
      @event_channel.push [key, args]
    end

    def stop
      @interfaces.each &:stop_service

      EventMachine.stop
    end

    def join
      @interfaces.each do |server|
        server.thread.join
      end
    end
  end
end
