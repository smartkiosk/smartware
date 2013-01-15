module Smartware
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

    def self.init
      trap 'CHLD', ProcessManager.method(:handle_sigchld)
    end
  end
end
