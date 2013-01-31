module Smartware
  class Service
    attr_reader :config, :amqp_connection, :amqp_channel
    attr_reader :amqp_general, :amqp_status, :amqp_commands

    def initialize(config_file)
      @config = YAML.load File.read(config_file)
      @interfaces = []
      @devices = []
      @amqp_connection = nil
      @amqp_channel = nil
      @amqp_commands = nil
    end

    def start
      EventMachine.epoll
      EventMachine.run do
        @amqp_connection = AMQP.connect host: @config["broker"]
        @amqp_channel = AMQP::Channel.new @connection
        @amqp_general = @amqp_channel.fanout "smartware.general"
        @amqp_status = @amqp_channel.topic "smartware.status"
        @amqp_commands = @amqp_channel.direct "smartware.commands"

        general_queue = @amqp_channel.queue "smartware.general"
        general_queue.bind @amqp_general
        general_queue.subscribe do |metadata, message|
          @devices.each do |device|
            device.general message
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

    def stop
      @interfaces.each &:stop_service

      @amqp_connection.close do
        EventMachine.stop
      end
    end

    def join
      @interfaces.each do |server|
        server.thread.join
      end
    end
  end
end

