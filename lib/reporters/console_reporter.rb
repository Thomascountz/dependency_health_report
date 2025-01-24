require_relative 'reporter'

class ConsoleReporter < Reporter
  def generate(dependency_freshness, cumulative_risk_profile, rating, cumulative_libyear_in_days)
    puts "Dependency Freshness Report:"

    dependency_freshness.each do |gem_name, data|
      version_distance = data.version_distance
      category = risk_category_from_distance(version_distance)

      puts "#{gem_name}:"
      puts "  Current Version: #{data.current_version}"
      puts "  Latest Version:  #{data.latest_version}"
      puts "  Version Distance: #{version_distance}"
      puts "  Risk Category:   #{category.to_s.capitalize}"
      puts "  Type:            #{data.is_direct ? "Direct" : "Transitive"}"
      puts "  Age in Days:     #{data.age_in_days}" if data.age_in_days
      puts "  Action: #{action_for_category(category)}"
    end

    puts "\nCumulative Risk Profile:"
    cumulative_risk_profile.each do |category, percentage|
      puts "  #{category.to_s.capitalize}: #{percentage.round(2)}%"
    end

    puts "\nDependency Freshness Rating: #{rating} stars"
    puts "\nCumulative Libyear in Days: #{cumulative_libyear_in_days}"
  end
end
