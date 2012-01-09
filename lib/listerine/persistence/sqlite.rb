require 'sqlite3'
module Listerine
  module Persistence
    class Sqlite
      METADATA_TABLE_NAME = "functional_monitors"
      RUN_HISTORY_TABLE_NAME = "run_history"
      DEFAULT_DB_PATH = "#{ENV['HOME']}/listerine-default.db"

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
        [METADATA_TABLE_NAME, RUN_HISTORY_TABLE_NAME].each do |table|
          @db.execute("DROP TABLE IF EXISTS #{table}")
        end

        create()
      end

      # Ensures that we have the appropriate tables for storing monitor data
      def create
        if @db.table_info(METADATA_TABLE_NAME).empty?
          @db.execute("CREATE TABLE #{METADATA_TABLE_NAME} (key varchar(1024) PRIMARY KEY, val varchar(8192))")
        end

        if @db.table_info(RUN_HISTORY_TABLE_NAME).empty?
          @db.execute("CREATE TABLE #{RUN_HISTORY_TABLE_NAME} (name varchar(1024), outcome varchar(16), time DATETIME)")
        end
      end

      def read(key)
        result = @db.execute("SELECT val FROM #{METADATA_TABLE_NAME} WHERE key=? LIMIT 1", key)
        result.empty? ? nil : result[0][0]
      end

      def write(key, value)
        if exists?(key)
          @db.execute("UPDATE #{METADATA_TABLE_NAME} SET val=? WHERE key=?", value.to_s, key)
        else
          @db.execute("INSERT INTO #{METADATA_TABLE_NAME} (key, val) VALUES (?, ?)", key, value.to_s)
        end
      end

      # Writes the +outcome+ of type Listerine::Outcome for a monitor +name+
      def write_outcome(name, outcome)
        time = outcome.time.to_s
        @db.execute("INSERT INTO #{RUN_HISTORY_TABLE_NAME} (name, outcome, time) VALUES (?, ?, ?)", name, outcome.result, time)
      end

      # Returns the collection of Listerine::Outcome objects for a given monitor +name+.
      def outcomes(name, opts = {})
        limit = sort = nil

        if opts[:limit]
          limit = " LIMIT #{opts[:limit]}"
        end

        if opts[:sort]
          sort = " ORDER BY #{opts[:sort]}"
        end

        outcomes = []
        results = @db.execute("SELECT outcome, time FROM #{RUN_HISTORY_TABLE_NAME} WHERE name=?#{sort}#{limit}", name)
        results.each do |r|
          outcomes << Listerine::Outcome.new(r[0], Time.parse(r[1]))
        end
        outcomes
      end

      def exists?(key)
        @db.execute("SELECT COUNT(*) FROM #{METADATA_TABLE_NAME} WHERE key=?", key)[0][0] > 0
      end

      def delete(key)
        @db.execute("DELETE FROM #{METADATA_TABLE_NAME} WHERE key=? LIMIT 1", key)
      end
    end
  end
end
