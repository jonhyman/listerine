require 'rubygems'
require 'bundler/setup'
require 'listerine' # and any other gems you need

RSpec.configure do |config|

  config.after(:each) do
    # Destroy all the persistence information on each new test
    Listerine::Options.instance.persistence_layer.destroy

    # Clear out the list of monitors to run
    Listerine::Runner.instance.monitors.clear
  end

  config.after(:suite) do
    # Delete the sqlite database file
    File.delete(Listerine::Options.instance.persistence_layer.path)
  end
end
