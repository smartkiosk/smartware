module Smartware
  module Interface
    class Interface
      attr_reader :config

      def initialize(config, service)
        @config = config
        @service = service

        @status_mutex = Mutex.new
        @status = {
          model: '',
          version: ''
        }

        iface = @config["name"]
        driver = @config["driver"]

        @iface_id = iface.underscore

        require "smartware/drivers/#{@iface_id}/#{driver.underscore}"

        @device = Smartware::Driver.const_get(iface.to_s)
                                   .const_get(driver.to_s)
                                   .new(config)

        @request_queue = @service.amqp_channel.queue(@iface_id, auto_delete: true)
        @request_queue.bind(@service.amqp_commands, routing_key: @iface_id)
        @request_queue.subscribe do |metadata, request|
          begin
            receive_request *JSON.load(request)
          rescue => e
            Logging.logger.error "Error in receive_request of #{@iface_id}: #{e}"
            e.backtrace.each { |line| Logging.logger.error line }
            Logging.logger.error "Original request: #{request}"
          end
        end
      end

      def general(message)
        if message == "update"
          @status_mutex.synchronize do
            @status.each do |key, value|
              publish_event key, value
            end
          end
        end
      end

      def error
        self.status[:error]
      end

      def model
        self.status[:model]
      end

      def version
        self.status[:version]
      end

      def status
        @status_mutex.synchronize { @status }
      end

      protected

      def update_status(key, value)
        @status_mutex.synchronize do
          if @status[key] != value
            @status[key] = value
            publish_event key, value
          end
        end
      end

      def receive_request(*request)
        Smartware::Logging.logger.warn "#{self.class.name} received request #{request.inspect}, but it's not implemented."
      end

      def publish_event(key, *data)
        @service.amqp_status.publish JSON.dump(data), routing_key: "#{@iface_id}.#{key}"
      end
    end
  end
end
