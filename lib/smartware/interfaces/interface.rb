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
      end

      def repush_events(connection)
        @status_mutex.synchronize do
          @status.each do |key, value|
            connection.publish_event "#{@iface_id}.#{key}", *value
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

      def update_status(key, *value)
        @status_mutex.synchronize do
          if @status[key] != value
            @status[key] = value
            publish_event key, *value
          end
        end
      end

      def publish_event(key, *data)
        @service.publish_event "#{@iface_id}.#{key}", *data
      end
    end
  end
end
