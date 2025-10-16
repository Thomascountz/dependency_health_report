require_relative "reporter"
require "sqlite3"

class SqliteReporter < Reporter
  def initialize(db_path = "out/dependency_freshness_report.db")
    @db = SQLite3::Database.new(db_path)
    create_table
  end

  def generate(dependency_freshness)
    dependency_freshness.each do |gem_name, data|
      @db.execute("INSERT OR REPLACE INTO reports (gem_name, current_version, latest_version, version_distance, age_in_days) VALUES (?, ?, ?, ?, ?)",
        [gem_name, data.current_version, data.latest_version, data.version_distance, data.age_in_days])
    end
    puts "SQLite report generated in #{@db.filename}"
  end

  private

  def create_table
    @db.execute <<-SQL
      DROP TABLE IF EXISTS reports;
    SQL

    @db.execute <<-SQL
      CREATE TABLE reports (
        id INTEGER PRIMARY KEY,
        gem_name TEXT UNIQUE,
        current_version TEXT,
        latest_version TEXT,
        version_distance INTEGER,
        age_in_days INTEGER
      );
    SQL

    @db.execute <<-SQL
      CREATE INDEX IF NOT EXISTS index_gem_name ON reports (gem_name);
    SQL
  end
end
