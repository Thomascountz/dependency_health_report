# frozen_string_literal: true

require "date"
require "logger"

require_relative "models"

class DependencyAnalyzer
  def initialize(logger: Logger.new($stderr))
    @logger = logger
  end

  def calculate_dependency_freshness(gem_name, gem_version, versions_metadata)
    current_version_info = versions_metadata.find { |version| version.number == gem_version }

    if current_version_info.nil?
      @logger.warn("Skipping comparison for #{gem_name}: installed version #{gem_version} missing from metadata")
      return
    end

    latest_version_info = if current_version_info.prerelease?
      versions_metadata.first
    else
      versions_metadata.find { |version| !version.prerelease? }
    end

    latest_version = latest_version_info.number
    current_version = current_version_info.number

    if latest_version == current_version
      return nil
    end

    latest_release_date = latest_version_info.created_at
    current_release_date = current_version_info.created_at

    version_distance = versions_metadata.index { |version| version.number == current_version }
    libyear_in_days = [(latest_release_date - current_release_date).to_i, 0].max

    Result.new(
      name: gem_name,
      current_version: gem_version,
      current_version_release_date: current_release_date,
      latest_version: latest_version,
      latest_version_release_date: latest_release_date,
      version_distance: version_distance,
      libyear_in_days: libyear_in_days,
      is_direct: true
    )
  end
end
