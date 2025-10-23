# frozen_string_literal: true

require_relative "../reporters/reporter"

# Simple reporter that captures results in memory without outputting anything
# Extends the Reporter base class from dependency_health_report
class DependencyReporter < Reporter
  def generate(_results)
    # No-op reporter used when storage needs the analyzer pipeline without output.
  end
end
