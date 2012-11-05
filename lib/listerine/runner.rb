require 'singleton'
module Listerine
  class Runner
    include Singleton

    def run
      monitors.each do |monitor|
        begin
          if monitor.environments.empty?
            outcome = monitor.run
            process_outcome(monitor.name, outcome)
          else
            monitor.environments.each do |env|
              outcome = monitor.run(:environment => env)
              process_outcome(monitor.name, outcome, env)
            end
          end
        rescue Exception => e
          Listerine::Logger.error("Uncaught exception running #{monitor.name}: #{e}")
        end
      end

      # Prune the database
      Listerine::Options.instance.persistence_layer.prune()
    end

    def add_monitor(monitor)
      # Raise an exception if a monitor with the same name already exists
      if self.monitors.select{|m| m.name == monitor.name}.length > 0
        raise ArgumentError.new("Monitor with name #{monitor.name} already exists.")
      end

      self.monitors << monitor
    end

    def monitors
      @monitors ||= []
    end

    private
    def process_outcome(name, outcome, env = nil)
      msg = "* #{name}"
      if env
        msg += " (#{env})"
      end

      if outcome.success?
        result = Listerine::Logger.success("PASS", false)
      elsif outcome.failure?
        result = Listerine::Logger.error("FAIL", false)
      elsif outcome.disabled?
        result = Listerine::Logger.warn("DISABLED", false)
      else
        result = Listerine::Logger.error("UNKNOWN RETURN VALUE: #{outcome.result}", false)
      end
      Listerine::Logger.info("#{msg}\t#{result}")
    end
  end
end
