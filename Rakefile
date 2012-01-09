require "bundler"
Bundler.setup

require "rake"
require "rspec"
require "rspec/core/rake_task"

$LOAD_PATH.unshift File.expand_path("../lib", __FILE__)
require "listerine/version"

task :gem => :build
task :build do
  system "gem build listerine.gemspec"
end

task :install => :build do
  system "sudo gem install listerine-#{Listerine::VERSION}.gem"
end

task :release => :build do
  system "git tag -a v#{Listerine::VERSION} -m 'Tagging #{Listerine::VERSION}'"
  system "git push --tags"
  system "gem push listerine-#{Listerine::VERSION}.gem"
end

RSpec::Core::RakeTask.new("spec:all") do |spec|
  spec.pattern = "spec/**/*_spec.rb"
end
task :spec => ["spec:all"]
task :default => :spec
