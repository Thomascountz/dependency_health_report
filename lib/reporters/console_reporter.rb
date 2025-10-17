# frozen_string_literal: true

require_relative "reporter"

class ConsoleReporter < Reporter
  def generate(results)
    results.each do |gem_name, data|
      puts "#{gem_name}:"
      puts "  Current Version:   #{data.current_version}"
      puts "  Current Released:  #{data.current_version_release_date || "Unknown"}"
      puts "  Latest Version:    #{data.latest_version || "Unknown"}"
      puts "  Latest Released:   #{data.latest_version_release_date || "Unknown"}"
      puts "  Version Distance:  #{data.version_distance.nil? ? "Unknown" : data.version_distance}"
      puts "  Libyear (days):    #{data.libyear_in_days.nil? ? "Unknown" : data.libyear_in_days}"
    end
  end
end
