require "em/protocols/line_protocol"

module Smartware
  class PubSubClient
    class Message
      attr_reader :key, :args

      def initialize(reliable_id, key, args, callback)
        @reliable_id = reliable_id
        @key = key
        @args = args
        @callback = callback
      end

      def reliable?
        !@reliable_id.nil?
      end

      def id
        @reliable_id
      end

      def acknowlege
        raise "message is not reliable" if @reliable_id.nil?

        @callback.call @reliable_id
      end

      def [](index)
        @args[index]
      end

      def to_a
        @args
      end
    end

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

        @client.receive data
      end

      def send_record(data)
        send_data(JSON.dump(data) + "\r\n")
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
      @reconnect_timer = EventMachine.add_timer 1, &method(:attempt)
    end

    def receive(data)
      message = Message.new data["reliable_id"],
                            data["key"],
                            data["args"],
                            ->(id) do

        @connection.send_record command: "acknowlege", id: id
      end

      @receiver.call message
    end

    private

    def attempt
      @reconnect_timer = nil
      @connection = EventMachine.connect @host, @port, PubSubHandler, self
    end
  end
end
