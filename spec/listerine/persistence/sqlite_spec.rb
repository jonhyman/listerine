require 'spec_helper'
describe Listerine::Persistence::Sqlite do
  let(:persistence) {Listerine::Persistence::Sqlite.new}
  let(:key) {"key"}
  let(:key2) {"key2"}
  let(:value) {"value"}
  let(:value2) {"value2"}
  let(:name) {"My monitor"}
  let(:env) {"production"}

  before :each do
    persistence.destroy
  end

  context "construction" do
    it "can set the database path via :path" do
      path = "testdb.db"
      p = Listerine::Persistence::Sqlite.new(:path => path)
      p.path.should == path
      File.exist?(path).should be true
      File.delete(path)
    end
  end

  context "#read" do
    it "reads a key" do
      persistence.write(key, value, env)
      persistence.read(key, env).should == value
    end
  end

  context "#write" do
    it "writes a key-value pair" do
      persistence.write(key, value, env)
      persistence.read(key, env).should == value
      persistence.write(key, value2, env)
      persistence.read(key, env).should == value2
    end
  end

  context "#exists?" do
    it "returns true if a given key exists" do
      persistence.write(key, value, env)
      persistence.exists?(key, env).should be true
    end

    it "returns false if a given key does not exist" do
      persistence.exists?(key, env).should be false
    end
  end

  context "#write_outcome" do
    it "writes the outcome for a given monitor name" do
      expect {
        persistence.write_outcome(name, Listerine::Outcome.new(true), env)
      }.to change{persistence.outcomes(name, env).length}.from(0).to(1)
    end
  end

  context "#outcomes" do
    it "returns a collection of Listerine::Outcome objects of a monitor's outcome" do
      now = Time.now
      ten_secs_ago = now - 10

      outcome1 = Listerine::Outcome.new(true, now)
      outcome2 = Listerine::Outcome.new(false, ten_secs_ago)

      persistence.write_outcome(name, outcome1, env)
      persistence.write_outcome(name, outcome2, env)

      outcomes = persistence.outcomes(name, env)
      outcomes.length.should == 2
      outcomes.first.result.should == outcome1.result
      outcomes.first.time.to_i.should == outcome1.time.to_i
      outcomes.last.result.should == outcome2.result
      outcomes.last.time.to_i.should == outcome2.time.to_i
    end

    it "can be limited" do
      now = Time.now
      ten_secs_ago = now - 10

      outcome1 = Listerine::Outcome.new(true, now)
      outcome2 = Listerine::Outcome.new(false, ten_secs_ago)

      persistence.write_outcome(name, outcome1, env)
      persistence.write_outcome(name, outcome2, env)

      outcomes = persistence.outcomes(name, env, :limit => 1)
      outcomes.length.should == 1
      outcomes.first.result.should == outcome1.result
    end

    it "can be sorted" do
      now = Time.now
      ten_secs_ago = now - 10

      outcome1 = Listerine::Outcome.new(true, now)
      outcome2 = Listerine::Outcome.new(false, ten_secs_ago)

      persistence.write_outcome(name, outcome1, env)
      persistence.write_outcome(name, outcome2, env)

      outcomes = persistence.outcomes(name, env, :sort => "time")
      outcomes.length.should == 2
      outcomes.first.result.should == outcome2.result
      outcomes.first.time.to_i.should == outcome2.time.to_i
      outcomes.last.result.should == outcome1.result
      outcomes.last.time.to_i.should == outcome1.time.to_i
    end

    it "can be both limited and sorted" do
      now = Time.now
      ten_secs_ago = now - 10

      outcome1 = Listerine::Outcome.new(true, now)
      outcome2 = Listerine::Outcome.new(false, ten_secs_ago)

      persistence.write_outcome(name, outcome1, env)
      persistence.write_outcome(name, outcome2, env)

      outcomes = persistence.outcomes(name, env, :sort => "time", :limit => 1)
      outcomes.length.should == 1
      outcomes.first.result.should == outcome2.result
      outcomes.first.time.to_i.should == outcome2.time.to_i
    end
  end

  context "#destroy" do
    it "drops and recreates the tables" do
      persistence.write(key, value, env)
      persistence.write(key2, value, env)
      persistence.write_outcome(name, Listerine::Outcome.new(true), env)
      persistence.destroy
      persistence.exists?(key, env).should be false
      persistence.exists?(key2, env).should be false
      persistence.outcomes(name, env).length.should == 0
    end
  end

  context "#monitors" do
    it "returns the list of monitor names that have been run" do
      Listerine::Monitor.new do
        name "foo"
        assert {true}
      end

      Listerine::Monitor.new do
        name "bar"
        assert {true}
      end

      Listerine::Runner.instance.run

      persistence.monitors.length.should == 2
      persistence.monitors.should include("foo")
      persistence.monitors.should include("bar")
    end
  end

  context "#environments" do
    it "returns a list of environments for a given monitor" do
      Listerine::Monitor.new do
        name "foo"
        environments :staging, :production
        assert {true}
      end

      Listerine::Monitor.new do
        name "bar"
        assert {true}
      end

      Listerine::Runner.instance.run

      persistence.environments("foo").length.should == 2
      persistence.environments("foo").should include("production")
      persistence.environments("foo").should include("staging")
      persistence.environments("bar").length.should == 1
      persistence.environments("bar").should include("default")
    end
  end

  context "#save_settings" do
    it "saves the name and description to the database" do
      m = Listerine::Monitor.new do
        name "My new monitor"
        assert {true}
        description "This is my description"
      end

      persistence.save_settings(m)
      persistence.get_settings(m.name).should == {:name => "My new monitor", :description => "This is my description"}
    end
  end

  context "#get_settings" do
    it "returns the name and description of a monitor" do
      m = Listerine::Monitor.new do
        name "My new monitor"
        assert {true}
        description "This is my description"
      end

      persistence.save_settings(m)
      persistence.get_settings(m.name).should == {:name => "My new monitor", :description => "This is my description"}
    end

    it "returns an empty hash if the monitor name doesn't exist." do
      persistence.get_settings("My monitor").should == {}
    end
  end

  context "#prune" do
    let(:name) {"foo"}
    let(:environment) {"bar"}

    it "deletes run history older than 3 days" do
      persistence.write_outcome(name, Listerine::Outcome.new(true, Time.now - (60 * 60 * 24 * 5)), environment)
      persistence.write_outcome(name, Listerine::Outcome.new(true, Time.now - (60 * 60 * 24 * 2)), environment)
      persistence.prune()
      persistence.outcomes(name, environment).length.should == 1
    end
  end
end
