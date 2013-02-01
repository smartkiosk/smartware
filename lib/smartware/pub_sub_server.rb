module Smartware
  class PubSubServer
    class PubSubConnection < EventMachine::Connection
      def initialize(server)
        @server = server
      end

      def post_init
        @server.add_connection self
      end

      def unbind
        @server.remove_connection self
      end

      def receive_data(data)

      end

      def publish_event(key, *args)
        send_data(JSON.dump({ key: key, args: args }) + "\r\n")
      end
    end

    attr_accessor :repush

    def initialize(host, port)
      @repush = nil
      @connections = Set.new

      EventMachine.start_server host, port, PubSubConnection, self
    end

    def add_connection(connection)
      @connections.add connection
      @repush.call connection
    end

    def remove_connection(connection)
      @connections.delete connection
    end

    def publish_event(key, *args)
      @connections.each do |connection|
        connection.publish_event key, *args
      end
    end
  end
end
