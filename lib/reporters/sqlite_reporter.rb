require_relative "reporter"
require "sqlite3"

class SqliteReporter < Reporter
  def initialize(db_path = "out/dependency_freshness_report.db")
    @db = SQLite3::Database.new(db_path)
    create_table
  end

  def generate(dependency_freshness)
    dependency_freshness.each do |gem_name, data|
      @db.execute(
        <<-SQL,
          INSERT OR REPLACE INTO reports (
            gem_name,
            current_version,
            latest_version,
            version_distance,
            libyear_in_days,
            status,
            status_message
          )
          VALUES (?, ?, ?, ?, ?, ?, ?)
        SQL
        [
          gem_name,
          data.current_version,
          data.latest_version,
          data.version_distance,
          data.libyear_in_days,
          data.status.to_s,
          nil
        ]
      )
    end
    puts "SQLite report generated in #{@db.filename}"
  end

  private

  def create_table
    @db.execute <<-SQL
      CREATE TABLE IF NOT EXISTS reports (
        id INTEGER PRIMARY KEY,
        gem_name TEXT UNIQUE,
        current_version TEXT,
        latest_version TEXT,
        version_distance INTEGER,
        libyear_in_days INTEGER,
        status TEXT,
        status_message TEXT
      );
    SQL

    @db.execute <<-SQL
      CREATE UNIQUE INDEX IF NOT EXISTS index_reports_on_gem_name ON reports (gem_name);
    SQL
  end
end
