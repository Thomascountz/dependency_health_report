# frozen_string_literal: true

require "bundler"
require "date"
require "logger"

require_relative "result"
class DependencyAnalyzer
  def initialize(gem_fetcher, logger: Logger.new($stderr))
    @gem_fetcher = gem_fetcher
    @logger = logger
  end

  def calculate_dependency_freshness(lockfile, as_of: nil)
    direct_dependencies = lockfile.dependencies.keys

    lockfile.specs.each_with_object({}) do |spec, results|
      next unless direct_dependencies.include?(spec.name)

      info = build_gem_info(spec, as_of: as_of)
      results[spec.name] = info if info
    end
  end

  private

  def build_gem_info(spec, as_of:)
    gem_name = spec.name
    current_version = spec.version&.to_s
    source_type = source_type_for(spec)

    unless source_type == :rubygems
      return log_and_skip("Skipping comparison for #{gem_name}: unsupported source #{source_type}")
    end

    unless spec.source.remotes&.any?
      return log_and_skip("Skipping comparison for #{gem_name}: unable to find remote URI")
    end

    remote_host = spec.source.remotes.first.host

    versions = @gem_fetcher.fetch_gem_versions(gem_name, remote_host: remote_host, as_of: as_of)
    unless versions&.any?
      return log_and_skip("Skipping comparison for #{gem_name}: no version metadata returned from #{remote_host}")
    end

    latest_version_info = versions.first
    latest_version = latest_version_info.number
    latest_release_date = latest_version_info.created_at
    current_version_info = versions.find { |version| version.number == current_version }

    unless current_version_info
      return log_and_skip("Skipping comparison for #{gem_name}: installed version #{current_version} missing from metadata")
    end

    current_release_date = current_version_info.created_at

    unless latest_release_date && current_release_date
      return log_and_skip("Skipping comparison for #{gem_name}: release date data is incomplete")
    end

    version_distance = versions.index { |version| version.number == current_version }
    unless version_distance
      return log_and_skip("Skipping comparison for #{gem_name}: installed version #{current_version} missing from metadata for as-of date")
    end

    libyear_in_days = [(latest_release_date - current_release_date).to_i, 0].max

    Result.new(
      name: gem_name,
      current_version: current_version,
      current_version_release_date: current_release_date,
      latest_version: latest_version,
      latest_version_release_date: latest_release_date,
      version_distance: version_distance,
      is_direct: true,
      libyear_in_days: libyear_in_days,
      status: :ok
    )
  end

  def log_and_skip(message)
    @logger.warn(message) if $verbose
    nil
  end

  def source_type_for(spec)
    source = spec.source
    return :none unless source

    if defined?(Bundler::Source::Git) && source.is_a?(Bundler::Source::Git)
      :git
    elsif defined?(Bundler::Source::Path) && source.is_a?(Bundler::Source::Path)
      :path
    elsif defined?(Bundler::Source::Rubygems) && source.is_a?(Bundler::Source::Rubygems)
      :rubygems
    else
      :unknown
    end
  end
end
