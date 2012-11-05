require 'spec_helper'
describe Listerine::Runner do
  context "#run" do
    it "runs all the monitors" do
      $global = 0
      $global2 = 0
      Listerine::Monitor.new do
        name "My monitor"
        assert do
          $global = 1
          true
        end
      end

      Listerine::Monitor.new do
        name "My other monitor"
        assert do
          $global2 = 2
          true
        end
      end

      Listerine::Runner.instance.run
      $global.should == 1
      $global2.should == 2
    end

    it "runs each monitor in each environment" do
      $global = 0
      $global2 = 0
      Listerine::Monitor.new do
        name "My monitor"
        environments :staging, :production
        assert do
          case current_environment
            when :staging
              $global = 1
            when :production
              $global2 = 2
            else
          end
          true
        end
      end

      Listerine::Runner.instance.run
      $global.should == 1
      $global2.should == 2
    end

    it "prunes the persistence layer" do
      Listerine::Options.instance.persistence_layer.should_receive(:prune)
      Listerine::Runner.instance.run
    end

    it "does not let exceptions from one monitor stop the other monitors from running" do
      $global = 0
      $global2 = 0
      m = Listerine::Monitor.new do
        name "My monitor"
        assert do
          $global = 1
          true
        end
      end

      Listerine::Monitor.new do
        name "My other monitor"
        assert do
          $global2 = 2
          true
        end
      end

      m.should_receive(:run).and_raise(ArgumentError.new)

      Listerine::Runner.instance.run
      $global.should == 0
      $global2.should == 2
    end
  end
end
