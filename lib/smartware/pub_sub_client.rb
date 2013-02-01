require "em/protocols/line_protocol"

module Smartware
  class PubSubClient
    class PubSubHandler < EventMachine::Connection
      include EventMachine::Protocols::LineProtocol

      def initialize(client)
        @client = client
      end

      def unbind
        @client.broken
      end

      def receive_line(line)
        data = JSON.load line

        @client.deliver data["key"], *data["args"]
      end
    end

    @@static_client = nil

    def self.create_static_client
      @@static_client = PubSubClient.new
    end

    def self.destroy_static_client
      return if @@static_client.nil?
      @@static_client.stop
      @@static_client = nil
    end

    attr_accessor :receiver

    def initialize(host = "localhost", port = 6100)
      @host = host
      @port = port
      @reconnect_timer = nil
      @connection = nil
    end

    def start
      attempt if @connection.nil? && @reconnect_timer.nil?
    end

    def stop
      @connection.close_connection unless @connection.nil?
      EventMachine.cancel_timer @reconnect_timer unless @reconnect_timer.nil?
    end

    def broken
      @connection = nil
      @reconnect_timer = EventMachine.set_timer 1, &method(:attempt)
    end

    def deliver(key, *args)
      @receiver.call key, *args
    end

    private

    def attempt
      @reconnect_timer = nil
      @connection = EventMachine.connect @host, @port, PubSubHandler, self
    end
  end
end
