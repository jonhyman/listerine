Listerine
=========

Listerine is a simple functional monitoring framework that allows you to quickly create script monitors which alert you
when they fail.

Listerine is not a process monitoring framework like [God](http://godrb.com) but instead intended for functional test
application monitoring.

This project was largely created as a self-service for Appboy because other monitoring solutions such as CloudKick are
too expensive for what amounts to a script running on a cron schedule.

You could use Listerine to:

* Ensure that your caching layer is functioning properly
* Make sure that you have X available Resque workers
* Check that your hosted database is online (e.g., if you use MongoHQ or RedisToGo)
* POST to your API and verify return values

Installation
------------

1. Install the gem

    gem install listerine

2. Write a Listerine monitor script
3. Setup a cron job to run the monitor script on some regular interval

    # Run the monitor script every 2 minutes
    $ crontab -e
    */2 * * * * /path/to/monitor/file.rb


Overview
--------

Listerine allows you to define simple script monitors that contain an <em>assertion</em>, which when true means that
the monitor has succeeded and when false means that the monitor has failed.

All monitors must contain a `name` and an `assert` block. All unhandled exceptions will be caught, treated as a
failure, and the exception text and backtrace will be sent in the notification. Here's an example:

```ruby
require 'mysql2'

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

This seems all well and good, but how does the monitor know who to notify if there is a failure? For that, we need to
configure the monitors.

Add this code before the `Listerine::Runner` to configure all the monitors to notify some email address on failure.

```ruby
Listerine::Monitor.configure do
  from "alerts@example.com" # the email address from which the alerts will be sent
  notify "jon@example.com"
end
```


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
criticality `level` on the monitor, and when defining recipients in the `configure` block, indicate which recipients
are for which criticality level. For example:

```ruby
Listerine::Monitor.configure do
  from "alerts@example.com"
  # When an alert fails that is of criticality level critical, notify critical@example.com
  notify "critical@example.com", :when => :critical
  notify "warn@example.com", :when => :not_critical
end

Listerine::Monitor.new do
  name "Resque workers"
  description "This monitor makes sure that there is at least 1 Resque worker."
  environments :staging, :production
  # This monitor is critical when running in the production environment
  level :critical, :in => :production
  level :not_critical, :in => :staging
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

If a recipient is not declared for a criticality level, no notification will be sent.

Criticality levels can be set globally in the `configure` block so you can make all production monitors critical, etc.


Customizing notification thresholds
-----------------------------------

You might not want to get notified the first time a monitor fails. When defining a monitor, you can define variables
to `notify_after` some number of consecutive failures, and then after you've received a notification, to
`notify_every` x failures after that.

These options can be defined locally on a monitor, or globally set in the `configure` block. By default, both values
are set to 1.

```ruby
Listerine::Monitor.new do
  name "Cache online"
  description "This monitor connects to the cache and tries to set and then get a key."
  # Don't notify until there have been 2 consecutive failures
  notify_after 2
  # After 2 failures, only send a new notification every 3 failures
  notify_every 3
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
consecutive failures. To do that, you can pass a block to `if_failing`, which will be yielded with the current
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

Global options
--------------

You can set the follow options globally in the `configure` block to avoid having to redefine on each monitor:

* `level`
* `notify_after`
* `notify_every`


Helper functions
----------------

Because a common use case we have is to check if a website is online, there is a simple helper `assert_online` which
creates an `assert` block to ensure that a website is returning a 200 status code.

```ruby
Listerine::Monitor.new do
  name "Site online"
  level :critical
  description "Makes sure that the site is online."
  assert_online "http://blog.example.com"
end
```

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
Listerine comes with a Sinatra-based front end for checking the latest status of your monitors and enabling/disabling
them on a per-environment basis.

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
