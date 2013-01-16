module Smartware
  module Interface
    class Interface
      attr_reader :config

      def initialize(config)
        @config = config
        @status_mutex = Mutex.new
        @status = {
          model: '',
          version: ''
        }

        iface = @config["name"]
        driver = @config["driver"]

        require "smartware/drivers/#{iface.underscore}/#{driver.underscore}"

        @device = Smartware::Driver.const_get(iface.to_s)
                                   .const_get(driver.to_s)
                                   .new(config)
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

      def update_status(&block)
        @status_mutex.synchronize &block
      end
    end
  end
end
