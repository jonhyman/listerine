require "lib/listerine/version"

Gem::Specification.new do |s|
  s.name        = 'Listerine'
  s.version     = Listerine::VERSION
  s.date        = '2012-01-06'
  s.summary     = "A simple monitoring framework."
  s.description = "A simple monitoring framework"
  s.authors     = "Jon Hyman"
  s.email       = "jon@appboy.com"
  s.files        = Dir.glob("lib/**/*") + %w(LICENSE README.md Rakefile)
  s.require_path = 'lib'
  s.homepage    = "http://rubygems.org/gems/hola"

  s.add_dependency("rest-client")
  s.add_dependency("pony")
  s.add_dependency("sqlite3")
  s.add_development_dependency("rspec")
end
