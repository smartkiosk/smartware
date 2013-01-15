module Smartware
  class Service
    attr_reader :config

    def initialize(config_file)
      @config = YAML.load File.read(config_file)
      @interfaces = []
    end

    def start
      @interfaces = @config["interfaces"].map do |config|
        interface = Smartware::Interface.const_get(config['name']).new config

        DRb::DRbServer.new @config["uri"], interface
      end
    end

    def stop
      @interfaces.each &:stop_service
    end

    def join
      @interfaces.each do |server|
        server.thread.join
      end
    end
  end
end

