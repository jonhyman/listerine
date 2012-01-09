require_relative "extensions/hash"
require_relative "extensions/array"
require_relative "listerine/logger"
require_relative "listerine/mailer"
require_relative "listerine/outcome"
require_relative "listerine/options"
require_relative "listerine/persistence/sqlite"
require_relative "listerine/runner"
require_relative "listerine/monitor"
require 'pony'
require 'rest-client'
require 'time'
#
#Listerine::Monitor.configure do
#  from "functional-monitors@appboy.com"
#  notify "critical@appboy.com", :when => :critical
#  notify "warn@appboy.com", :when => :warn
#  level :critical, :in => :production
#  level :warn, :in => :staging
#  notify_after 1
#  notify_every 1
#  persistence :sqlite
#end
#
#Listerine::Monitor.new do
#  name "Test monitor"
#  environments :staging, :production
#  description "Does something"
#  assert do
#    true
#  end
#  if_failing do |failure_count|
#    puts("failing with failure count #{failure_count}")
#  end
#end
#
#Listerine::Runner.instance.run
