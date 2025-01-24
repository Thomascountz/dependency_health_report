require_relative 'reporter'
require 'sqlite3'

class SqliteReporter < Reporter
  def initialize(db_path = "out/dependency_freshness_report.db")
    super()
    @db = SQLite3::Database.new(db_path)
    create_table
  end

  def generate(dependency_freshness, cumulative_risk_profile, rating, cumulative_libyear_in_days)
    dependency_freshness.each do |gem_name, data|
      category = risk_category_from_distance(data.version_distance)
      @db.execute("INSERT INTO reports (gem_name, current_version, latest_version, version_distance, risk_category, type, age_in_days, action) VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
        [gem_name, data.current_version, data.latest_version, data.version_distance, category.to_s.capitalize, data.is_direct ? "Direct" : "Transitive", data.age_in_days, action_for_category(category)])
    end
    puts "SQLite report generated in #{@db.filename}"
  end

  private

  def create_table
    @db.execute <<-SQL
      CREATE TABLE IF NOT EXISTS reports (
        id INTEGER PRIMARY KEY,
        gem_name TEXT,
        current_version TEXT,
        latest_version TEXT,
        version_distance INTEGER,
        risk_category TEXT,
        type TEXT,
        age_in_days INTEGER,
        action TEXT
      );
    SQL
  end
end
