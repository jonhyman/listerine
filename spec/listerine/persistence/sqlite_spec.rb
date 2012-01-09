require 'spec_helper'
describe Listerine::Persistence::Sqlite do
  let(:persistence) {Listerine::Persistence::Sqlite.new}
  let(:key) {"key"}
  let(:key2) {"key2"}
  let(:value) {"value"}
  let(:value2) {"value2"}
  let(:name) {"foo"}


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
      persistence.write(key, value)
      persistence.read(key).should == value
    end
  end

  context "#write" do
    it "writes a key-value pair" do
      persistence.write(key, value)
      persistence.read(key).should == value
      persistence.write(key, value2)
      persistence.read(key).should == value2
    end
  end

  context "#exists?" do
    it "returns true if a given key exists" do
      persistence.write(key, value)
      persistence.exists?(key).should be true
    end

    it "returns false if a given key does not exist" do
      persistence.exists?(key).should be false
    end
  end

  context "#write_outcome" do
    it "writes the outcome for a given monitor name" do
      expect {
        persistence.write_outcome(name, Listerine::Outcome.new(true))
      }.to change{persistence.outcomes(name).length}.from(0).to(1)
    end
  end

  context "#outcomes" do
    it "returns a collection of Listerine::Outcome objects of a monitor's outcome" do
      now = Time.now
      ten_secs_ago = now - 10

      outcome1 = Listerine::Outcome.new(true, now)
      outcome2 = Listerine::Outcome.new(false, ten_secs_ago)

      persistence.write_outcome(name, outcome1)
      persistence.write_outcome(name, outcome2)

      outcomes = persistence.outcomes(name)
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

      persistence.write_outcome(name, outcome1)
      persistence.write_outcome(name, outcome2)

      outcomes = persistence.outcomes(name, :limit => 1)
      outcomes.length.should == 1
      outcomes.first.result.should == outcome1.result
    end

    it "can be sorted" do
      now = Time.now
      ten_secs_ago = now - 10

      outcome1 = Listerine::Outcome.new(true, now)
      outcome2 = Listerine::Outcome.new(false, ten_secs_ago)

      persistence.write_outcome(name, outcome1)
      persistence.write_outcome(name, outcome2)

      outcomes = persistence.outcomes(name, :sort => "time")
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

      persistence.write_outcome(name, outcome1)
      persistence.write_outcome(name, outcome2)

      outcomes = persistence.outcomes(name, :sort => "time", :limit => 1)
      outcomes.length.should == 1
      outcomes.first.result.should == outcome2.result
      outcomes.first.time.to_i.should == outcome2.time.to_i
    end
  end

  context "#destroy" do
    it "drops and recreates the tables" do
      persistence.write(key, value)
      persistence.write(key2, value)
      persistence.write_outcome(name, Listerine::Outcome.new(true))
      persistence.destroy
      persistence.exists?(key).should be false
      persistence.exists?(key2).should be false
      persistence.outcomes(name).length.should == 0
    end
  end
end
