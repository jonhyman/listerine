require 'singleton'
module Listerine
  class Options
    DEFAULT_NOTIFY_EVERY = 1
    DEFAULT_NOTIFY_AFTER = 1
    DEFAULT_FROM = "functional-monitors@example.com"
    include Singleton
    attr_accessor :levels, :recipients

    def initialize
      @levels = []

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
      end
      @recipients << recip
    end

    # Sets the persistence layer for the monitors
    def persistence(type, opts = {})
      if type == :sqlite
        @persistence = Listerine::Persistence::Sqlite.new(opts)
      end
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
      return nil if @recipients.nil?

      if level.nil?
        return nil if @recipients.empty?
        recip = @recipients.first
      else
        # For default levels, no level should be set with the recipient.
        if level == :default
          level = nil
        end
        recip = @recipients.select {|r| r[:level] == level}
        return nil if recip.empty?
        recip = recip.first
      end
      recip[:email]
    end

    def notify_every(*val)
      if val.empty?
        @notify_every ||= DEFAULT_NOTIFY_EVERY
      else
        @notify_every = val.first
      end
    end

    def notify_after(*val)
      if val.empty?
        @notify_after ||= DEFAULT_NOTIFY_AFTER
      else
        @notify_after = val.first
      end
    end

    def level(*args)
      opts = args.extract_options!
      @levels ||= []

      if args.empty?
        if @levels.length == 1 && @levels.first[:environment].nil?
          @levels.first[:level]
        else
          level = @levels.select {|l| l[:environment] == current_environment }
          if level.empty?
            :default
          else
            level.first[:level]
          end
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
