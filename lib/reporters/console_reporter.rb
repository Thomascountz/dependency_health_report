require_relative "reporter"

class ConsoleReporter < Reporter
  def generate(dependency_freshness)
    puts "Dependency Freshness Report:"

    dependency_freshness.each do |gem_name, data|
      puts "#{gem_name}:"
      puts "  Current Version:  #{data.current_version}"
      puts "  Latest Version:   #{data.latest_version}"
      puts "  Version Distance: #{data.version_distance}"
      puts "  Age in Days:      #{data.age_in_days || "Unknown"}"
    end
  end
end
