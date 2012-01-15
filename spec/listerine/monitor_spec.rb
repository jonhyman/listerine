require 'spec_helper'
describe Listerine::Monitor do
  after :each do
    # Ensure that we clear out the recipients since Listerine::Options is a singleton.
    Listerine::Options.instance.recipients.clear
    Listerine::Options.instance.levels.clear
  end

  context "construction" do
    it "requires the name to be defined" do
      expect {
        Listerine::Monitor.new do
          description "Should fail without a name"
          assert {true}
        end
      }.to raise_error(ArgumentError)
    end

    it "requires the name to be non-empty" do
      expect {
        Listerine::Monitor.new do
          name ""
          assert {true}
        end
      }.to raise_error(ArgumentError)
    end

    it "raises an ArgumentError if another monitor with the same name exists" do
      Listerine::Monitor.new do
        name "My monitor"
        assert {true}
      end

      expect {
        Listerine::Monitor.new do
          name "My monitor"
          assert {true}
        end
      }.to raise_error(ArgumentError)
    end

    it "has its settings persisted" do
      persistence = Listerine::Persistence::Sqlite.new
      persistence.get_settings("My monitor").should == {}
      Listerine::Monitor.new do
        name "My monitor"
        assert {true}
        description "My description"
      end
      persistence.get_settings("My monitor").should == {:name => "My monitor", :description => "My description"}
    end
  end

  context "#configure" do
    # Because Listerine::Options is a singleton, we need to clear out the values we set in these tests
    after :each do
      Listerine::Monitor.configure do
        notify_every nil
        notify_after nil
      end
    end

    it "configures default values for notify_every" do
      Listerine::Monitor.configure do
        notify_every 3
      end

      m = Listerine::Monitor.new do
        name "My monitor"
        assert {true}
      end

      m.notify_every.should == 3
    end

    it "configures default values for notify_after" do
      Listerine::Monitor.configure do
        notify_after 4
      end

      m = Listerine::Monitor.new do
        name "My monitor"
        assert {true}
      end

      m.notify_after.should == 4
    end
  end

  context "#name" do
    it "can be set on construction" do
      m = Listerine::Monitor.new do
        name "My monitor"
        assert {true}
      end
      m.name.should == "My monitor"
    end
  end

  context "#description" do
    it "can be set on construction" do
      m = Listerine::Monitor.new do
        name "My monitor"
        description "My monitor description"
        assert {true}
      end
      m.description.should == "My monitor description"
    end
  end

  context "#notify_after" do
    it "defaults to Listerine::Options::DEFAULT_NOTIFY_AFTER" do
      m = Listerine::Monitor.new do
        name "My monitor"
        assert {true}
      end
      m.notify_after.should == Listerine::Options::DEFAULT_NOTIFY_AFTER
    end

    it "can be set on construction" do
      m = Listerine::Monitor.new do
        name "My monitor"
        notify_after 2
        assert {true}
      end
      m.notify_after.should == 2
    end

    it "sets the threshold of failures after which a notification is sent" do
      Listerine::Monitor.configure do
        notify "jon@example.com"
      end

      m = Listerine::Monitor.new do
        name "My monitor"
        notify_after 3
        assert {false}
      end

      Listerine::Mailer.should_receive(:mail).once
      3.times { m.run }
    end

    # This is split out into another test because the spec can't set the expectation that it will receive the
    # call on the xth time.
    it "sets the threshold of failures before which no notifications are sent" do
      Listerine::Monitor.configure do
        notify "jon@example.com"
      end

      m = Listerine::Monitor.new do
        name "My monitor"
        notify_after 3
        assert {false}
      end

      Listerine::Mailer.should_not_receive(:mail)
      2.times { m.run }
    end
  end

  context "#notify_every" do
    it "defaults to Listerine::Options::DEFAULT_NOTIFY_EVERY" do
      m = Listerine::Monitor.new do
        name "My monitor"
        assert {true}
      end
      m.notify_every.should == Listerine::Options::DEFAULT_NOTIFY_EVERY
    end

    it "can be set on construction" do
      m = Listerine::Monitor.new do
        name "My monitor"
        notify_every 2
        assert {true}
      end
      m.notify_every.should == 2
    end

    it "sets the threshold of failures after the first one which notifications are sent" do
      Listerine::Monitor.configure do
        notify "jon@example.com"
      end

      m = Listerine::Monitor.new do
        name "My monitor"
        notify_after 3
        notify_every 2
        assert {false}
      end

      Listerine::Mailer.should_receive(:mail).exactly(3).times
      7.times { m.run }
    end
  end

  context "#environments" do
    it "can be set on construction" do
      m = Listerine::Monitor.new do
        name "My monitor"
        environments :staging, :production
        assert {true}
      end
      m.environments.should == [:staging, :production]
    end
  end

  context "#assert" do
    it "creates a code block to be run when the monitor is #run" do
      $global = 0
      m = Listerine::Monitor.new do
        name "My monitor"
        assert do
          $global = 10
          true
        end
      end
      m.run
      $global.should == 10
    end
  end

  context "#notify" do
    it "emails the recipient if no levels are set" do
      Listerine::Monitor.configure do
        notify "jon@example.com"
      end

      m = Listerine::Monitor.new do
        name "My monitor"
        assert {true}
      end
      Listerine::Mailer.should_receive(:mail).with("jon@example.com", anything, anything)
      m.notify
    end

    it "emails the recipient for the level" do
      Listerine::Monitor.configure do
        notify "crit@example.com", :when => :critical
        notify "warn@example.com", :when => :warning
      end

      m = Listerine::Monitor.new do
        name "My monitor"
        assert {true}
      end
      Listerine::Mailer.should_receive(:mail).with("warn@example.com", anything, anything).once
      # Set the current level
      m.stub(:level).and_return(:warning)
      m.notify

      Listerine::Mailer.should_receive(:mail).with("crit@example.com", anything, anything).once
      # Set the current level
      m.stub(:level).and_return(:critical)
      m.notify
    end

    it "does not email anyone if the recipient for that level is not set" do
      Listerine::Monitor.configure do
        notify "jon@example.com"
      end

      m = Listerine::Monitor.new do
        name "My monitor"
        level :critical
        assert {true}
      end
      Listerine::Mailer.should_not_receive(:mail)
      m.notify
    end
  end

  context "#level" do
    it "defines a criticality level for a monitor" do
      m = Listerine::Monitor.new do
        name "My monitor"
        level :critical
        assert {true}
      end
      m.level.should == :critical
    end

    it "can be set per environment" do
      m = Listerine::Monitor.new do
        name "My monitor"
        environments :staging, :production
        level :critical, :in => :production
        level :warning, :in => :staging
        assert {true}
      end

      # Stub the current environment
      m.stub(:current_environment).and_return(:production)
      m.level.should == :critical
      m.stub(:current_environment).and_return(:staging)
      m.level.should == :warning
    end

    it "can be set globally" do
      Listerine::Monitor.configure do
        level :critical, :in => :production
        level :warning, :in => :staging
      end

      m = Listerine::Monitor.new do
        name "My monitor"
        environments :staging, :production
        assert {true}
      end

      # Stub the current environment
      m.stub(:current_environment).and_return(:production)
      m.level.should == :critical
      m.stub(:current_environment).and_return(:staging)
      m.level.should == :warning
    end
  end

  context "#run" do
    it "runs the monitor statement in the assert" do
      $global = 0
      m = Listerine::Monitor.new do
        name "My monitor"
        assert do
          $global = 10
          true
        end
      end
      m.run
      $global.should == 10
    end

    it "can take in the environment" do
      $global = 0
      m = Listerine::Monitor.new do
        name "My monitor"
        assert do
          if current_environment == :production
            $global = 10
          else
            $global = 100
          end
          true
        end
      end
      m.run(:environment => :production)
      $global.should == 10
      m.run(:environment => :staging)
      $global.should == 100
    end

    it "returns the outcome for the assert" do
      # When assert returns true
      m = Listerine::Monitor.new do
        name "My monitor"
        assert do
          true
        end
      end

      outcome = m.run
      outcome.should be_instance_of(Listerine::Outcome)
      outcome.result.should == Listerine::Outcome.new(true).result

      # When assert returns false
      m = Listerine::Monitor.new do
        name "My other monitor"
        assert do
          false
        end
      end

      outcome = m.run
      outcome.should be_instance_of(Listerine::Outcome)
      outcome.result.should == Listerine::Outcome.new(false).result
    end

    it "does not run the assert and returns a disabled outcome if the monitor is disabled" do
      m = Listerine::Monitor.new do
        name "My monitor"
        assert do
          true
        end
      end

      m.disable

      outcome = m.run
      outcome.should be_instance_of(Listerine::Outcome)
      outcome.result.should == Listerine::Outcome::DISABLED
    end

    it "raises a TypeError if the assert does not return a true or false value" do
      m = Listerine::Monitor.new do
        name "My monitor"
        assert do
          "true"
        end
      end

      expect {
        m.run
      }.to raise_error(TypeError)
    end

    it "notifies the recipient if the monitor fails" do
      Listerine::Monitor.configure do
        notify "jon@example.com"
      end

      m = Listerine::Monitor.new do
        name "My monitor"
        assert do
          false
        end
      end

      Listerine::Mailer.should_receive(:mail).with("jon@example.com", anything, anything)

      m.run
    end

    it "does not notify the recipient if the monitor succeeds" do
      Listerine::Monitor.configure do
        notify "jon@example.com"
      end

      m = Listerine::Monitor.new do
        name "My monitor"
        assert do
          true
        end
      end

      Listerine::Mailer.should_not_receive(:mail)

      m.run
    end

    it "returns a failed outcome if the monitor throws an exception" do
      m = Listerine::Monitor.new do
        name "My monitor"
        assert do
          raise StandardError.new
        end
      end

      outcome = m.run
      outcome.result.should == Listerine::Outcome.new(false).result
    end

    it "contains the exception text and backtrace in the notification sent on a monitor failure" do
      Listerine::Monitor.configure do
        notify "jon@example.com"
      end

      m = Listerine::Monitor.new do
        name "My monitor"
        assert do
          raise StandardError.new("Exception!")
        end
      end

      StandardError.any_instance.stub(:backtrace).and_return("backtrace")
      Listerine::Mailer.should_receive(:mail).with("jon@example.com", anything, "Monitor failure: My monitor. Failure count: 0\nUncaught exception running My monitor: Exception!. Backtrace: backtrace")
      m.run
    end
  end

  context "#disable" do
    it "disables the monitor" do
      m = Listerine::Monitor.new do
        name "My monitor"
        assert {true}
      end

      expect {
        m.disable
      }.to change{m.disabled?}.from(false).to(true)
    end
  end

  context "#enable" do
    it "enables the monitor" do
      m = Listerine::Monitor.new do
        name "My monitor"
        assert {true}
      end

      m.disable
      m.should be_disabled
      m.enable
      m.should_not be_disabled
    end
  end

  context "#disabled?" do
    it "returns true if the monitor is disabled" do
      m = Listerine::Monitor.new do
        name "My monitor"
        assert {true}
      end

      m.disable
      m.should be_disabled
    end

    it "returns false if the monitor is enabled" do
      m = Listerine::Monitor.new do
        name "My monitor"
        assert {true}
      end

      m.should_not be_disabled
    end
  end

  context "disabling and enabling" do
    it "can be done on a per-environment basis" do
      m = Listerine::Monitor.new do
        name "My monitor"
        assert {true}
        environments :staging, :production
      end

      m.disable(:staging)
      m.disabled?(:staging).should be true
      m.disabled?(:production).should be false

      m.enable(:staging)
      m.disabled?(:staging).should be false
      m.disabled?(:production).should be false
    end
  end

  context "#if_failing" do
    it "creates a code block to be run if the monitor has failed" do
      $global = 0
      m = Listerine::Monitor.new do
        name "My monitor"
        assert do
          false
        end
        if_failing do
          $global = 10
        end
      end

      m.run

      $global.should == 10
    end

    it "is not called if the monitor succeeds" do
      $global = 0
      m = Listerine::Monitor.new do
        name "My monitor"
        assert do
          true
        end
        if_failing do
          $global = 10
        end
      end

      m.run

      $global.should == 0
    end

    it "is yielded the failure count of the monitor" do
      $global = 0
      m = Listerine::Monitor.new do
        name "My monitor"
        assert do
          false
        end
        if_failing do |failure_count|
          $global = failure_count
        end
      end

      5.times do |i|
        m.run
        $global.should == i+1
      end
    end
  end

  context "#assert_online" do
    it "when run, returns true if a url returns 200 to a GET" do
      m = Listerine::Monitor.new do
        name "My monitor"
        assert_online "http://www.example.com"
      end

      response = mock('response', :code => 400)
      RestClient.stub(:get).with("http://www.example.com").and_return(response)
      outcome = m.run
      outcome.result.should == Listerine::Outcome.new(false).result
    end

    it "when run, returns false if a url does not return 200 to a GET" do
      m = Listerine::Monitor.new do
        name "My monitor"
        assert_online "http://www.example.com"
      end

      response = mock('response', :code => 200)
      RestClient.stub(:get).with("http://www.example.com").and_return(response)
      outcome = m.run
      outcome.result.should == Listerine::Outcome.new(true).result
    end

    [:post, :get, :delete, :put].each do |type|
      it "can use other HTTP types such as #{type.to_s.upcase}" do
        m = eval("Listerine::Monitor.new do; name 'My monitor'; assert_online 'http://www.example.com', :#{type}; end;")
        response = mock('response', :code => 200)
        RestClient.stub(type).with("http://www.example.com").and_return(response)
        outcome = m.run
        outcome.result.should == Listerine::Outcome.new(true).result
      end
    end
  end
end
