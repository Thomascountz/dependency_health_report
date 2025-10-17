# frozen_string_literal: true

Dir[File.join(__dir__, "lib", "**", "*.rb")].each { |file| require file }

require "bundler"
require "date"

class DependencyHealthReport
  def initialize(lockfile_data, analyzer:, reporters:, as_of: nil)
    @lockfile_data = lockfile_data
    @direct_dependencies = lockfile_data.dependencies.keys
    @analyzer = analyzer
    @reporters = reporters
    @as_of = as_of
  end

  def run
    dependency_freshness = @analyzer.calculate_dependency_freshness(@lockfile_data, as_of: @as_of)
    @reporters.each do |reporter|
      reporter.generate(dependency_freshness)
    end
  end
end
