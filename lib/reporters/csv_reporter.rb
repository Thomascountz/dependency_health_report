# frozen_string_literal: true

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
        "Libyear (Days)",
        "Status"
      ]

      dependency_freshness.each do |gem_name, data|
        csv << [
          gem_name,
          data.current_version,
          data.latest_version,
          data.version_distance,
          data.libyear_in_days,
          data.status
        ]
      end
    end
    puts "CSV report generated at #{file_path}"
  end
end
