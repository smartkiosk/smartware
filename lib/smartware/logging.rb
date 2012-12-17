require 'logger'

module Smartware
  module Logging

    def self.logdir=(dir)
      @logdir = dir
    end

    def self.logger
      @logger ||= begin
        log = Logger.new(STDOUT)
        log.level = Logger::INFO
        log
      end
    end

    def self.logger=(val)
      @logger = (val ? val : Logger.new('/dev/null'))
    end

    def self.logfile=(val)
      @logfile = val
    end

    def self.logfile
      @logfile
    end

  end
end