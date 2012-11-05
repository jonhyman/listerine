module Listerine
  module Persistence
    class PersistenceLayer
      # Destroys and recreates the database
      def destroy
        raise NotImplementedError.new("Subclasses must implement this.")
      end

      def save_settings(monitor)
        raise NotImplementedError.new("Subclasses must implement this.")
      end

      def get_settings(name)
        raise NotImplementedError.new("Subclasses must implement this.")
      end

      # Creates the database
      def create
        raise NotImplementedError.new("Subclasses must implement this.")
      end

      def read(key, environment)
        raise NotImplementedError.new("Subclasses must implement this.")
      end

      def write(key, value, environment)
        raise NotImplementedError.new("Subclasses must implement this.")
      end

      def disable(name, environment)
        raise NotImplementedError.new("Subclasses must implement this.")
      end

      def enable(name, environment)
        raise NotImplementedError.new("Subclasses must implement this.")
      end

      def disabled?(name, environment)
        raise NotImplementedError.new("Subclasses must implement this.")
      end

      # Writes the +outcome+ of type Listerine::Outcome for a monitor +name+ in +environment+
      def write_outcome(name, outcome, environment)
        raise NotImplementedError.new("Subclasses must implement this.")
      end

      # Returns the collection of Listerine::Outcome objects for a given monitor +name+.
      def outcomes(name, environment, opts = {})
        raise NotImplementedError.new("Subclasses must implement this.")
      end

      def exists?(key, environment)
        raise NotImplementedError.new("Subclasses must implement this.")
      end

      def delete(key, environment)
        raise NotImplementedError.new("Subclasses must implement this.")
      end
      
      def prune
        raise NotImplementedError.new("Subclasses must implement this.")
      end

      # Returns an array of strings of the monitor names
      def monitors
        raise NotImplementedError.new("Subclasses must implement this.")
      end

      # Returns an array of strings of the environment names for monitor with +name+
      def environments(name)
        raise NotImplementedError.new("Subclasses must implement this.")
      end

      class << self
        def inherited(subclass)
          if superclass.respond_to?(:inherited)
            superclass.inherited(subclass)
          end
          @subclasses ||= []
          @subclasses << subclass
        end

        def subclasses
          @subclasses
        end
      end
    end
  end
end
