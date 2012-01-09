module Listerine
  class Monitor
    attr_reader :name, :description, :environments, :notify_after, :notify_every, :levels, :current_environment

    def self.configure(&block)
      Listerine::Options.instance.configure(&block)
    end

    def initialize(&block)
      instance_eval(&block)
      # Name and assert fields are required for all monitors
      assert_field(:name)
      assert_field(:assert)

      Listerine::Runner.instance.add_monitor(self)
    end

    # Runs the monitor defined in the #assert call and returns a Listerine::Outcome.
    def run(*args)
      opts = args.extract_options!
      @current_environment = opts[:environment]

      if self.disabled?
        Listerine::Outcome.new(Listerine::Outcome::DISABLED)
      else
        begin
          result = @assert.call
        rescue Exception => e
          Listerine::Logger.error("Uncaught exception running #{self.name}: #{e}")
          result = false
        end

        # Ensure that we have a boolean value from the assert call.
        unless result.instance_of?(TrueClass) || result.instance_of?(FalseClass)
          raise TypeError.new("Assertions must return a boolean value. Monitor #{self.name} returned #{result}.")
        end

        outcome = Listerine::Outcome.new(result)
        update_stats(outcome)

        track_failures(outcome) do |failure_count|
          # Notify after notify_after failures, but then only notify every notify_every failures.
          if failure_count >= self.notify_after &&
              (failure_count == self.notify_after || ((self.failure_count + self.notify_after) % self.notify_every == 0))
            notify
          end

          if @if_failing.kind_of?(Proc)
            @if_failing.call(failure_count)
          end
        end

        outcome
      end
    end

    def track_failures(outcome)
      if outcome.success?
        count = 0
      else
        count = failure_count()
        count += 1

        yield count
      end

      self.persistence.write(failure_count_key(), count)
    end

    def failure_count
      self.persistence.read(failure_count_key()).to_i || 0
    end

    def failure_count_key
      "#{persistence_key()}_failures"
    end

    # Allows you to disable a monitor
    def disable
      self.persistence.write(disable_key(), true)
    end

    # Re enables a monitor
    def enable
      self.persistence.write(disable_key(), false)
    end

    # Returns true if a monitor is disabled
    def disabled?
      disabled_value = self.persistence.read(disable_key)
      !disabled_value.nil? && disabled_value == true.to_s
    end

    def notify
      recipient = Listerine::Options.instance.recipient(level())
      if recipient
        subject = "Monitor failure: #{name}"
        body = "Monitor failure: #{name}. Failure count: #{failure_count}"

        if self.current_environment
          subject = "[#{self.current_environment.upcase}] #{subject}"
        end

        Listerine::Mailer.mail(recipient, subject, body)
      else
        Listerine::Logger.print("Not notifying because there is no recipient. Level = #{level}")
      end
    end

    def if_failing(&block)
      @if_failing = lambda { |failure_count| instance_exec(failure_count, &block) }
    end

    def assert(&block)
      @assert = lambda { instance_eval(&block) }
    end

    # Sets the assert block that a +url+ returns 200 when hit via HTTP +method+ (default to GET)
    def assert_online(url, method = :get)
      http_status_ok = 200

      assert do
        begin
          rc = RestClient.__send__(method, url)
          code = rc.code
        rescue Exception => e
          code = nil
        end

        if code != http_status_ok
          Listerine::Logger.error("#{url} returned status code #{code}")
        end

        code == http_status_ok
      end
    end

    def name(*val)
      get_set_property(:name, *val)
    end

    def description(*val)
      get_set_property(:description, *val)
    end

    def environments(*envs)
      @environments ||= []

      if envs.empty?
        @environments
      else
        @environments = envs
        envs.each do |env|
          self.class.__send__(:define_method, "#{env}?") do
            self.current_environment == env
          end
        end
      end
    end

    def notify_every(*val)
      get_set_property(:notify_every, *val)
    end

    def notify_after(*val)
      get_set_property(:notify_after, *val)
    end

    def persistence_key
      self.current_environment.nil? ? name : "#{name}_#{self.current_environment}"
    end

    def persistence
      Listerine::Options.instance.persistence_layer
    end

    def level(*args)
      opts = args.extract_options!
      @levels ||= Listerine::Options.instance.levels

      if args.empty?
        if @levels.length == 1 && @levels.first[:environment].nil?
          @levels.first[:level]
        else
          level = @levels.select {|l| l[:environment] == self.current_environment }
          if level.empty?
            :default
          else
            level.first[:level]
          end
        end
      else
        name = args.first

        # If the leveling is set from Listerine::Options, then override it.
        @levels.delete_if {|k,v| k == :level && v == name}
        if opts[:in]
          @levels << {:level => name, :environment => opts[:in]}
        else
          @levels << {:level => name}
        end
      end
    end

    def disable_key
      "#{persistence_key()}_disabled"
    end

    def update_stats(outcome)
      self.persistence.write_outcome(self.name, outcome)
    end

    protected
    # Sets a +property+ if provided as a second argument. Otherwise, it returns the value of +property+, which defaults
    # to the value set in Listerine::Options
    def get_set_property(property, *args)
      property_as_inst = "@#{property}".to_sym

      if args.empty?
        val = instance_variable_get(property_as_inst)
        if val.nil? && Listerine::Options.instance.respond_to?(property)
          val = Listerine::Options.instance.__send__(property)
        end
        val
      else
        val = args.first
        if val.respond_to?(:strip)
          val = val.strip
        end
        instance_variable_set(property_as_inst, val)
      end
    end

    # Raises an ArgumentError if the field +field+ is not defined on the Monitor.
    def assert_field(field)
      attribute = instance_variable_get("@#{field}".to_sym)
      if attribute.nil? || (attribute.respond_to?(:empty?) && attribute.empty?)
        raise ArgumentError.new("#{field} is required for all monitors.")
      end
    end

  end
end
