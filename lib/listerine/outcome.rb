module Listerine
  class Outcome
    SUCCESS = "success"
    FAILURE = "failure"
    DISABLED = "disabled"

    attr_reader :result, :time
    def initialize(result, time = Time.now)
      if result.instance_of?(TrueClass)
        result = SUCCESS
      end

      if result.instance_of?(FalseClass)
        result = FAILURE
      end

      @result = result
      @time = time
    end

    def success?
      @result == SUCCESS
    end

    def failure?
      @result == FAILURE
    end

    def disabled?
      @result == DISABLED
    end
  end
end
