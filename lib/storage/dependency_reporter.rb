# frozen_string_literal: true

require_relative "../reporters/reporter"

# Simple reporter that captures results in memory without outputting anything
# Extends the Reporter base class from dependency_health_report
class DependencyReporter < Reporter
  attr_reader :results

  def initialize
    @results = []
  end

  def generate(results)
    @results = results
  end
end
