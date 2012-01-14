#!/usr/bin/env ruby
$LOAD_PATH.unshift File.dirname(__FILE__) + '/../lib'
require 'listerine/server'

use Rack::ShowExceptions

run Rack::URLMap.new \
  "/" => Listerine::Server.new
