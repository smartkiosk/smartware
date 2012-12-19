require 'thread'
require 'yaml'
require 'smartware/logging'

module Smartware
  module Service

    def self.config
      @config
    end

    def self.start(config_file)
      $stdout.sync = true
      
      @config = YAML.load File.read(File.expand_path(config_file))

      Smartware::Logging.logger = Logger.new($stdout)
      Smartware::Logging.logger.info "Smartware started at #{Time.now}"

      @threads = %w(smartware/interfaces/cash_acceptor
                      smartware/interfaces/printer
                      smartware/interfaces/modem).inject([]){|arr, iface| arr << Thread.new{ require iface } }

      @threads.map(&:join)
    rescue => e
      Smartware::Logging.logger.fatal e.message
      Smartware::Logging.logger.fatal e.backtrace.join("\n")
    end

    def self.stop
      @threads.map(&:kill)
      Smartware::Logging.logger.info "Smartware shutdown at #{Time.now}"
      exit 0
    end

  end
end

