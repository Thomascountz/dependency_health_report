require_relative "reporter"
require "csv"

class CsvReporter < Reporter
  def generate(dependency_freshness, cumulative_risk_profile, rating, cumulative_libyear_in_days, file_path = "out/dependency_freshness_report.csv")
    CSV.open(file_path, "wb") do |csv|
      csv << [
        "Gem Name",
        "Current Version",
        "Latest Version",
        "Version Distance",
        "Risk Category",
        "Type",
        "Age in Days",
        "Action"
      ]

      dependency_freshness.each do |gem_name, data|
        category = risk_category_from_distance(data.version_distance)
        csv << [
          gem_name,
          data.current_version,
          data.latest_version,
          data.version_distance,
          category.to_s.capitalize,
          data.is_direct ? "Direct" : "Transitive",
          data.age_in_days,
          action_for_category(category)
        ]
      end
    end
    puts "CSV report generated at #{file_path}"
  end
end
