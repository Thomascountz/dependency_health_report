require_relative "reporter"
require "csv"

class CsvReporter < Reporter
  def generate(dependency_freshness, file_path: "out/dependency_freshness_report.csv")
    CSV.open(file_path, "wb") do |csv|
      csv << [
        "Gem Name",
        "Current Version",
        "Latest Version",
        "Version Distance",
        "Age in Days"
      ]

      dependency_freshness.each do |gem_name, data|
        csv << [
          gem_name,
          data.current_version,
          data.latest_version,
          data.version_distance,
          data.age_in_days
        ]
      end
    end
    puts "CSV report generated at #{file_path}"
  end
end
