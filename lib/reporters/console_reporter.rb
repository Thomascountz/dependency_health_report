require_relative "reporter"

class ConsoleReporter < Reporter
  def generate(dependency_freshness)
    puts "Dependency Freshness Report:"

    dependency_freshness.each do |gem_name, data|
      puts "#{gem_name}:"
      puts "  Status:            #{data.status}"
      puts "  Current Version:   #{data.current_version}"
      puts "  Latest Version:    #{data.latest_version || "Unknown"}"
      puts "  Version Distance:  #{data.version_distance.nil? ? "Unknown" : data.version_distance}"
      libyear_display = data.libyear_in_days.nil? ? "Unknown" : data.libyear_in_days
      puts "  Libyear (days):    #{libyear_display}"
    end
  end
end
