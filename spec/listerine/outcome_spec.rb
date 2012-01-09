require 'spec_helper'
describe Listerine::Outcome do
  context "#success?" do
    it "returns true if the result is true" do
      Listerine::Outcome.new(true).should be_success
    end

    it "returns true if the result is Listerine::Outcome::SUCCESS" do
      Listerine::Outcome.new(Listerine::Outcome::SUCCESS).should be_success
    end

    it "returns false if the result is neither" do
      Listerine::Outcome.new(false).should_not be_success
      Listerine::Outcome.new(Listerine::Outcome::DISABLED).should_not be_success
    end
  end

  context "#failure?" do
    it "returns true if the result is false" do
      Listerine::Outcome.new(false).should be_failure
    end

    it "returns true if the result is Listerine::Outcome::FAILURE" do
      Listerine::Outcome.new(Listerine::Outcome::FAILURE).should be_failure
    end

    it "returns false if the result is neither" do
      Listerine::Outcome.new(true).should_not be_failure
      Listerine::Outcome.new(Listerine::Outcome::DISABLED).should_not be_failure
    end
  end

  context "#disabled?" do
    it "returns true if the result is Listerine::Outcome::DISABLED" do
      Listerine::Outcome.new(true).should be_success
    end

    it "returns true if the result is Listerine::Outcome::DISABLED" do
      Listerine::Outcome.new(Listerine::Outcome::DISABLED).should be_disabled
    end

    it "returns false if the result is not DISABLED" do
      Listerine::Outcome.new(false).should_not be_disabled
      Listerine::Outcome.new(true).should_not be_disabled
    end
  end
end
