require 'sqlite3'
module Listerine
  module Persistence
    class Sqlite
      METADATA_TABLE_NAME = "functional_monitors"
      RUN_HISTORY_TABLE_NAME = "run_history"
      DISABLED_MONITOR_TABLE_NAME = "disabled_monitors"
      DEFAULT_DB_PATH = "#{ENV['HOME']}/listerine-default.db"
      DEFAULT_ENV_NAME = "default"

      attr_reader :path

      # Creates a new Sqlite3 database specified at opts[:path] or DEFAULT_DB_PATH.
      def initialize(opts = {})
        if opts[:path]
          @path = opts[:path]
        else
          @path = DEFAULT_DB_PATH
        end

        @db = SQLite3::Database.new(@path)

        create()
      end

      # Destroys the database information and recreates the table structures
      def destroy
        [METADATA_TABLE_NAME, RUN_HISTORY_TABLE_NAME, DISABLED_MONITOR_TABLE_NAME].each do |table|
          @db.execute("DROP TABLE IF EXISTS #{table}")
        end

        create()
      end

      # Ensures that we have the appropriate tables for storing monitor data
      def create
        if @db.table_info(METADATA_TABLE_NAME).empty?
          stmt = "CREATE TABLE #{METADATA_TABLE_NAME} (key VARCHAR(1024), val VARCHAR(8192), env VARCHAR(255))"
          @db.execute(stmt)
        end

        if @db.table_info(RUN_HISTORY_TABLE_NAME).empty?
          stmt = "CREATE TABLE #{RUN_HISTORY_TABLE_NAME} (name VARCHAR(1024), outcome VARCHAR(16), env VARCHAR(255), time DATETIME)"
          @db.execute(stmt)
        end

        if @db.table_info(DISABLED_MONITOR_TABLE_NAME).empty?
          stmt = "CREATE TABLE #{DISABLED_MONITOR_TABLE_NAME} (name VARCHAR(1024), env VARCHAR(255))"
          @db.execute(stmt)
        end
      end

      def read(key, environment)
        environment = prepare_environment(environment)
        result = @db.execute("SELECT val FROM #{METADATA_TABLE_NAME} WHERE key=? AND env=? LIMIT 1", key, environment)
        result.empty? ? nil : result[0][0]
      end

      def write(key, value, environment)
        environment = prepare_environment(environment)
        if exists?(key, environment)
          @db.execute("UPDATE #{METADATA_TABLE_NAME} SET val=? WHERE key=? AND env=?", value.to_s, key, environment)
        else
          stmt = "INSERT INTO #{METADATA_TABLE_NAME} (key, val, env) VALUES (?, ?, ?)"
          @db.execute(stmt, key, value.to_s, environment)
        end
      end

      def disable(name, environment)
        environment = prepare_environment(environment)
        @db.execute("INSERT INTO #{DISABLED_MONITOR_TABLE_NAME} (name, env) VALUES (?, ?)", name, environment)
      end

      def enable(name, environment)
        environment = prepare_environment(environment)
        @db.execute("DELETE FROM #{DISABLED_MONITOR_TABLE_NAME} WHERE name=? AND env=?", name, environment)
      end

      def disabled?(name, environment)
        environment = prepare_environment(environment)
        @db.execute("SELECT COUNT(*) FROM #{DISABLED_MONITOR_TABLE_NAME} WHERE name=? AND env=?", name, environment)[0][0] > 0
      end

      # Writes the +outcome+ of type Listerine::Outcome for a monitor +name+ in +environment+
      def write_outcome(name, outcome, environment)
        environment = prepare_environment(environment)
        time = outcome.time.to_s
        stmt = "INSERT INTO #{RUN_HISTORY_TABLE_NAME} (name, outcome, time, env) VALUES (?, ?, ?, ?)"
        @db.execute(stmt, name, outcome.result, time, environment)
      end

      # Returns the collection of Listerine::Outcome objects for a given monitor +name+.
      def outcomes(name, environment, opts = {})
        environment = prepare_environment(environment)
        limit = sort = nil

        if opts[:limit]
          limit = " LIMIT #{opts[:limit]}"
        end

        if opts[:sort]
          sort = " ORDER BY #{opts[:sort]}"
        end

        outcomes = []
        results = @db.execute("SELECT outcome, time FROM #{RUN_HISTORY_TABLE_NAME} WHERE name=? AND env=?#{sort}#{limit}", name, environment)
        results.each do |r|
          outcomes << Listerine::Outcome.new(r[0], Time.parse(r[1]))
        end
        outcomes
      end

      def exists?(key, environment)
        environment = prepare_environment(environment)
        @db.execute("SELECT COUNT(*) FROM #{METADATA_TABLE_NAME} WHERE key=? AND env=?", key, environment)[0][0] > 0
      end

      def delete(key, environment)
        environment = prepare_environment(environment)
        @db.execute("DELETE FROM #{METADATA_TABLE_NAME} WHERE key=? AND env=? LIMIT 1", key, environment)
      end

      def monitors
        @db.execute("SELECT DISTINCT name FROM #{RUN_HISTORY_TABLE_NAME}").map {|r| r[0]}
      end

      def environments(name)
        @db.execute("SELECT DISTINCT env FROM #{RUN_HISTORY_TABLE_NAME} WHERE name=?", name).map {|r| r[0]}
      end

      private
      # Don't support null environments
      def prepare_environment(environment)
        environment.nil? ? DEFAULT_ENV_NAME : environment.to_s
      end
    end
  end
end
