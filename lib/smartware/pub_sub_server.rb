require "em/protocols/line_protocol"

module Smartware
  class PubSubServer
    class PubSubConnection < EventMachine::Connection
      include EventMachine::Protocols::LineProtocol

      def initialize(server)
        @server = server
      end

      def post_init
        @server.add_connection self
      end

      def unbind
        @server.remove_connection self
      end

      def receive_line(line)
        begin
          data = JSON.load line

          case data["command"]
          when "acknowlege"
            @server.acknowlege_reliable data["id"]

          else
            raise "unsupported command #{data["command"]}"
          end
        rescue => e
          Logging.logger.warn e.to_s
          e.backtrace.each { |line| Logging.logger.warn line }
        end
      end

      def publish_event(key, *args)
        send_data(JSON.dump({ key: key, args: args }) + "\r\n")
      end

      def publish_reliable_event(id, key, *args)
        send_data(JSON.dump({ reliable_id: id, key: key, args: args }) + "\r\n")
      end
    end

    attr_accessor :repush

    def initialize(host, port)
      @repush = nil
      @connections = Set.new
      @redis = Redis.new

      EventMachine.start_server host, port, PubSubConnection, self
    end

    def add_connection(connection)
      @connections.add connection
      @repush.call connection

      @redis.hgetall("smartware:reliable_events").each do |key, data|
        data = JSON.load(data)

        connection.publish_reliable_event key, data["key"], data["args"]
      end
    end

    def remove_connection(connection)
      @connections.delete connection
    end

    def publish_event(key, *args)
      @connections.each do |connection|
        connection.publish_event key, *args
      end
    end

    def publish_reliable_event(key, *args)
      id = (Time.now.to_f * 1000000).round.to_s

      @redis.hset "smartware:reliable_events", id, JSON.dump({ key: key, args: args })

      @connections.each do |connection|
        connection.publish_reliable_event id, key, args
      end
    end

    def acknowlege_reliable(id)
      @redis.hdel "smartware:reliable_events", id
    end
  end
end
