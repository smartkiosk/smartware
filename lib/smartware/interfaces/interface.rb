module Smartware
  module Interface
    class Interface
      attr_reader :config

      def initialize(config)
        @config = config

        iface = @config["name"]
        driver = @config["driver"]

        require "smartware/drivers/#{iface.underscore}/#{driver.underscore}"

        @device = Smartware::Driver.const_get(iface.to_s)
                                   .const_get(driver.to_s)
                                   .new(config)
      end
    end
  end
end
