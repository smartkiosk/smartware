module Smartware
  class Service
    attr_reader :config, :amqp_connection, :amqp_channel
    attr_reader :amqp_general, :amqp_status, :amqp_commands

    def initialize(config_file)
      @config = YAML.load File.read(config_file)
      @devices = []
      @amqp_connection = nil
      @amqp_channel = nil
      @amqp_commands = nil
    end

    def start
      EventMachine.epoll
      EventMachine.run do
        @amqp_connection = AMQP.connect @config["broker"]
        @amqp_channel = AMQP::Channel.new @connection
        @amqp_general = @amqp_channel.fanout "smartware.general", auto_delete: true
        @amqp_status = @amqp_channel.topic "smartware.status", auto_delete: true
        @amqp_commands = @amqp_channel.direct "smartware.commands", auto_delete: true

        general_queue = @amqp_channel.queue '', exclusive: true
        general_queue.bind @amqp_general
        general_queue.subscribe do |metadata, message|
          @devices.each do |device|
            device.general message
          end
        end

        @devices = @config["interfaces"].map do |config|
          Smartware::Interface.const_get(config['name']).new config, self
        end

        unless @config["connection_timeout"].nil?
          monitor = ConnectionMonitor.new @config["connection_timeout"].to_i, self

          monitor.run
        end
      end
    end

    def stop
      @amqp_connection.close do
        EventMachine.stop
      end
    end
  end
end

