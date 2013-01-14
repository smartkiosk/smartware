require 'thread'
require 'yaml'

module Smartware
  module Service

    def self.config
      @config
    end

    def self.start(config_file)
      $stdout.sync = true

      @config = YAML.load File.read(File.expand_path(config_file))

      Smartware::Logging.logger.info "Smartware started at #{Time.now}"

      @threads = %w(modem
                    cash_acceptor
                    printer
                 ).inject([]) do |arr, iface|
                        arr << Thread.new do
                          begin
                            driver = Service.config["#{iface}_driver"].downcase

                            require "smartware/drivers/#{iface}/#{driver}"
                            require "smartware/interfaces/#{iface}"
                          rescue => e
                            Logging.logger.fatal "During startup of #{iface}:"
                            Logging.logger.fatal e.message
                            Logging.logger.fatal e.backtrace.join("\n")
                          end
                        end
                      end

      @threads.map(&:join)
    rescue => e
      Logging.logger.fatal e.message
      Logging.logger.fatal e.backtrace.join("\n")
    end

    def self.stop
      @threads.map(&:kill)
      Logging.logger.info "Smartware shutdown at #{Time.now}"
      exit 0
    end

  end

  module ProcessManager
    def self.track(pid, method)
      @tracked ||= {}
      @tracked[pid] = method
    end

    def self.untrack(pid)
      @tracked ||= {}
      @tracked.delete pid
    end

    def self.handle_sigchld(signal)
      pids = []
      @tracked ||= {}

      begin
        loop do
          pid = Process.wait(-1, Process::WNOHANG)
          break if pid.nil?

          pids << pid
        end
      rescue
      end

      pids.each do |pid|
        tracker = @tracked[pid]
        unless tracker.nil?
          @tracked.delete pid
          tracker.call pid
        end
      end
    end
  end

  trap 'CHLD', ProcessManager.method(:handle_sigchld)
end

