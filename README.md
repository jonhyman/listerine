Listerine
=========

Listerine is a simple functional monitoring framework that enables you to quickly create customizable functional
monitors with full alerting capability.

Listerine is not a process monitoring framework like [God](http://godrb.com) but instead intended for functional test
application monitoring.

This project was originally created as a self-service for [Appboy](http://www.appboy.com) as a replacement to more
expensive services.

Listerine enables you to monitor all levels of your web applications and services. Some common examples include:

* Ensure that your caching layer is functioning properly
* Make sure that you have X available Resque workers
* Make sure that your Resque Scheduler agent is online
* Check that your hosted database is online (e.g., if you use MongoHQ or RedisToGo)
* POST to your API and verify return values

Installation
------------

    gem install listerine

Overview
--------

Listerine allows you to define simple script monitors that contain an <em>assertion</em>. When the assertion is true,
the monitor has succeeded. When the assertion evaluates to false the monitor is marked as failed, sends a notification,
and can run optional code on failure.

All monitors must contain both `name` and `assert` blocks. Unhandled exceptions are caught and treated as
failures, with the exception text and backtrace included in the notification. Here's an example:

```ruby
require 'mysql2'

# Global configuration settings
Listerine::Monitor.configure do
  # Configure the email address from which the alerts will be sent
  from "alerts@example.com"

  # Notify jon@example.com on all failures
  notify "jon@example.com"
end

# Define the monitor
Listerine::Monitor.new do
  name "Database online"
  description "This monitor ensures that the database is online."
  assert do
    # Connect to MySQL. If the host is down, this will raise a Mysql2::Error exception, which will automatically
    # be caught by the Listerine::Runner handler, treated as a failure, and the exception text and backtrace will
    # be sent in the notification.
    Mysql2::Client.new(:host => "host", :username => "test_user")
    true
  end
end

# Run all the monitors -- declare all monitors before this line
Listerine::Runner.instance.run
```

To run this file regularly, schedule a cron job such as the below to run monitors every 2 minutes.

    */2 * * * * /path/to/monitor/file.rb

Multiple environments
---------------------

The same monitor can be run in multiple environments. To do so, specify a list of `environments` when defining the
monitor. In your `assert` block, you will have access to a method `current_environment` which indicates the environment
in which the monitor is running.

When no environment is specified, the monitor is run in the `:default` environment.

```ruby
require 'resque'
Listerine::Monitor.new do
  name "Resque workers"
  description "This monitor makes sure that there is at least 1 Resque worker."
  environments :staging, :production
  assert do
    if current_environment == :staging
      url = "redis://staging:password@staging.example.com:6379"
    else
      url = "redis://production:password@production.example.com:6379"
    end
    redis_info = URI.parse(url)
    Resque.redis = Redis.new(:host => redis_info.host, :port => redis_info.port, :password => redis_info.password)
    Resque.workers.length > 0
  end
end

# Run all the monitors
Listerine::Runner.instance.run
```

When using multiple environments, you can also define different recipients for the failure notification. Set a
criticality level on the monitor using `is`, and when defining recipients in the `configure` block, indicate which
recipients are for which criticality level. Criticality levels are arbitrary symbols that you can define. In this
example we'll use `:critical` but it could be whatever you want.

```ruby
Listerine::Monitor.configure do
  from "alerts@example.com"
  # This is the default recipient
  notify "default@example.com"

  # When an alert fails that is of criticality level critical, notify critical@example.com
  notify "critical@example.com", :when => :critical
end

Listerine::Monitor.new do
  name "Resque workers"
  description "This monitor makes sure that there is at least 1 Resque worker."
  environments :staging, :production
  # This monitor is critical when running in the production environment
  is :critical, :in => :production
  # The criticality levels can be anything you want. It defaults to :default to notify the default recipient.
  is :foobar, :in => :staging
  assert do
    # Setup a different connection based on the current environment
    if current_environment == :staging
      url = "redis://staging:password@staging.example.com:6379"
    else
      url = "redis://production:password@production.example.com:6379"
    end
    redis_info = URI.parse(url)
    Resque.redis = Redis.new(:host => redis_info.host, :port => redis_info.port, :password => redis_info.password)
    Resque.workers.length > 0
  end
end

# Run all the monitors
Listerine::Runner.instance.run
```

If a recipient is not declared for a criticality level, Listerine will use the default recipient.

Criticality levels can be set globally in the `configure` block so you can make all production monitors `:critical`,
etc.

Note: You don't need to use multiple environments to set criticality levels. These are perfectly valid monitors:

 ```ruby
 Listerine::Monitor.configure do
  notify "alerts-warning@example.com"
  notify "alerts-critical@example.com", :when => :critical
 end

 Listerine::Monitor.new do
  name "Site online"
  is :critical
  assert do
    # Some code to check that the site is online
  end
 end

 Listerine::Monitor.new do
  name "Internal wiki online"
  assert do
    ...
  end
 end
 ```


Customizing notification thresholds
-----------------------------------

You might not want to get notified the first time a monitor fails. When defining a monitor, you can define variables
to `notify_after` some number of consecutive failures, and after you've received a notification, to
`then_notify_every` every x failures after that.

These options can be defined locally on a monitor, or globally set in the `configure` block. By default, both values
are set to 1.

```ruby
Listerine::Monitor.new do
  name "Cache online"
  description "This monitor connects to the cache and tries to set and then get a key."
  # Don't notify until there have been 2 consecutive failures
  notify_after 2
  # After 2 failures, only send a new notification every 3 failures
  then_notify_every 3
  assert do
    # Connect to cache
    cache = ...
    # Set key to value, then ensure that you can pull it from the cache
    cache.set("key", "value")
    cache.get("key") == "value"
  end
end
```


Adding custom actions for failures
----------------------------------

When a monitor fails, you might want to take custom action. For example, you might want to reboot a machine after 5
consecutive failures. To do that, you can pass a block to `if_failing`, which will be yielded to with the current
consecutive failure count.

Listerine also provides a wrapper around sending mail, `Listerine::Mailer.mail(to, subject, body)` if you want to add
custom notifications.

```ruby
Listerine::Monitor.new do
  name "Cache online"
  description "This monitor connects to the cache and tries to set and then get a key."
  assert do
    ...
  end

  # Reboot the cache instance if there are 5 consecutive failures
  if_failing do |failure_count|
    if failure_count == 5
      Listerine::Mailer.mail("jon@example.com", "Rebooting the cache", "Cache failed 5 times, rebooting")
      system("ec2-reboot-instances i-1234567")
    end
  end
end
```


Configure Options
--------------
The following are the global options you can set in the `configure` block.

* `from`: The email address from which your notifications are sent
* `notify` with an optional `:in => :environment`: The recipients of notifications


You can set the follow options globally in the `configure` block to avoid having to redefine on each monitor:

* `is` - defaults to `:default`
* `notify_after` - defaults to `1`
* `then_notify_every` - defaults to `1`


Helper functions
----------------

Because a common use case we have is to check if a website is online, there is a simple helper `assert_online` which
creates an `assert` block to ensure that a website is returning a 200 status code.

```ruby
Listerine::Monitor.new do
  name "Site online"
  is :critical
  description "Makes sure that the site is online."
  assert_online "http://blog.example.com"
end
```

We use CloudFlare, and CloudFlare is somewhat flaky, so you can pass in `:ignore_502 => true` to ignore 502 errors.

Notes
-----
The `name` field must be unique across all defined monitors.

Right now the persistence for these monitors is stored in a Sqlite3 database which is stored by default at
ENV["HOME"]/listerine-default.db. You can customize the path to this database in the `configure` block:

```ruby
Listerine::Monitor.configure do
  persistence :sqlite, :path => "/data/monitors/functional.db"
end
```


Listerine Server
================
Listerine comes with a Sinatra-based front end, `Listerine::Server`, for checking the latest status of your monitors and enabling/disabling
them on a per-environment basis.

Check `examples/config.ru` for a functional example (including HTTP basic auth).

Installation
------------
### Passenger

See Phusion's guide:

Apache: <http://www.modrails.com/documentation/Users%20guide%20Apache.html#_deploying_a_rack_based_ruby_application>

Nginx: <http://www.modrails.com/documentation/Users%20guide%20Nginx.html#deploying_a_rack_app>

### Rack::URLMap

If you want to load Listerine on a subpath, possibly alongside other apps, it's easy to do with Rack's `URLMap`.

I don't really recommend this, since using a Sqlite backend, it means that your application server must also run
the monitors, but you could conceptually do this if you want.

``` ruby
require 'listerine/server'

run Rack::URLMap.new \
  "/"       => Your::App.new,
  "/monitors" => Listerine::Server.new
```

Check `examples/config.ru` for a functional example (including HTTP basic auth).

### Rails 3

You can also mount Listerine on a subpath in your existing Rails 3 app by adding `require listerine/server` to the
top of your routes file or in an initializer then adding this to `routes.rb`.

``` ruby
mount Listerine::Server.new, :at => "/monitors"
```

Notes
-----

The Listerine server will pick up any monitors that have any run history, meaning if you delete a monitor it will still
show up. For now, simply delete your Sqlite database and it will be recreated the next time the monitors run.

Contributing
============
1. [Fork](http://help.github.com/fork-a-repo/) listerine
2. Create a topic branch - `git checkout -b my_branch`
3. Push to your branch - `git push origin my_branch`
4. Create a [Pull Request](http://help.github.com/pull-requests/) from your branch
5. That's it!
