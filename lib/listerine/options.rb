require 'singleton'
module Listerine
  class Options
    DEFAULT_LEVEL = :default
    DEFAULT_NOTIFY_EVERY = 1
    DEFAULT_NOTIFY_AFTER = 1
    DEFAULT_FROM = "functional-monitors@example.com"
    include Singleton
    attr_accessor :levels, :recipients

    def initialize
      @levels = [{:level => DEFAULT_LEVEL}]
      @recipients = []

      # Set the default persistence to Sqlite
      persistence(:sqlite)
    end

    def configure(&block)
      instance_eval(&block)
    end

    # Method to define which email address to notify on monitor failure.
    def notify(email, opts = {})
      @recipients ||= []
      recip = {:email => email}
      if opts[:when]
        recip[:level] = opts[:when]
      else
        recip[:level] = DEFAULT_LEVEL
      end
      @recipients << recip
    end

    # Sets the persistence layer for the monitors
    def persistence(type, opts = {})
      klass = type.to_s.capitalize
      @persistence = Listerine::Persistence::const_get(klass).new(opts)
    end

    # Retrieves the instantiated persistence layer
    def persistence_layer
      @persistence
    end

    # Defines the from email address for notifications. Defaults to DEFAULT_FROM
    def from(*val)
      if val.empty?
        @from ||= DEFAULT_FROM
      else
        @from = val.first
      end
    end

    def recipient(level)
      return nil if @recipients.empty?

      recip = @recipients.select {|r| r[:level] == level}

      # If we don't have a recipient, return the recipient for default level
      if recip.empty? && level != DEFAULT_LEVEL
        return recipient(DEFAULT_LEVEL)
      end

      return nil if recip.empty?
      recip = recip.first
      recip[:email]
    end

    def then_notify_every(*val)
      if val.empty?
        @then_notify_every ||= DEFAULT_NOTIFY_EVERY
      else
        @then_notify_every = val.first
      end
    end

    def notify_after(*val)
      if val.empty?
        @notify_after ||= DEFAULT_NOTIFY_AFTER
      else
        @notify_after = val.first
      end
    end

    def is(*args)
      opts = args.extract_options!
      # TODO - clean up levels and recipients
      if args.empty?
        level = @levels.select {|l| l[:environment] == current_environment }
        if level.empty?
          DEFAULT_LEVEL
        else
          level.first[:level]
        end
      else
        name = args.first
        if opts[:in]
          @levels << {:level => name, :environment => opts[:in]}
        else
          @levels << {:level => name}
        end
      end
    end
  end
end
