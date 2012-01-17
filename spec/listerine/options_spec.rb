require 'spec_helper'

# Tests which use Listerine::Options are exercised in monitor_spec.
describe Listerine::Options do
  describe "#recipient" do
    it "returns the default recipient if there is none for that level" do
      Listerine::Monitor.configure do
        notify "jon@appboy.com"
        notify "bill@appboy.com", :in => :production
      end

      Listerine::Options.instance.recipient(:staging).should == "jon@appboy.com"
    end
  end
end
