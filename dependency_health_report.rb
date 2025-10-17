# frozen_string_literal: true

Dir[File.join(__dir__, "lib", "**", "*.rb")].each { |file| require file }

require "bundler"
require "date"

class DependencyHealthReport
  def initialize(dependency_manifest, analyzer:, reporter:)
    @dependency_manifest = dependency_manifest
    @analyzer = analyzer
    @reporter = reporter
  end

  def run(as_of: nil)
    dependency_freshness = @analyzer.calculate_dependency_freshness(@dependency_manifest)
    @reporter.generate(dependency_freshness)
  end
end
