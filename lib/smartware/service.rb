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


      @threads = %w(smartware/interfaces/modem
                    smartware/interfaces/cash_acceptor
                    smartware/interfaces/printer
                 ).inject([]) do |arr, iface|
                        arr << Thread.new do
                          begin
                            require iface
                          rescue => e
                            Smartware::Logging.logger.fatal "During startup of #{iface}:"
                            Smartware::Logging.logger.fatal e.message
                            Smartware::Logging.logger.fatal e.backtrace.join("\n")
                          end
                        end
                      end

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

          break if pid == 0

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

