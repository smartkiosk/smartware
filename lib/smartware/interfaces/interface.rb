module Smartware
  module Interface
    class Interface
      attr_reader :config

      def initialize(config, service)
        @config = config
        @service = service

        @status_mutex = Mutex.new
        @status = {
          error: [ nil ],
          model: [ '' ],
          version: [ '' ]
        }

        iface = @config["name"]
        driver = @config["driver"]

        @iface_id = iface.underscore

        require "smartware/drivers/#{@iface_id}/#{driver.underscore}"

        @device = Smartware::Driver.const_get(iface.to_s)
                                   .const_get(driver.to_s)
                                   .new(config)
      end

      def shutdown(callback)
        if @device.respond_to? :shutdown
          @device.shutdown callback

          true
        else
          false
        end
      end

      def repush_events(connection)
        @status_mutex.synchronize do
          @status.each do |key, value|
            connection.publish_event "#{@iface_id}.#{key}", *value
          end
        end
      end

      def error
        self.status[:error][0]
      end

      def model
        self.status[:model][0]
      end

      def version
        self.status[:version][0]
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

      def publish_reliable_event(key, *data)
        @service.publish_reliable_event "#{@iface_id}.#{key}", *data
      end
    end
  end
end
