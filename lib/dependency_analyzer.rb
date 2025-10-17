# frozen_string_literal: true

require "bundler"
require "date"
require "logger"

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
      return unresolved_source_info(
        gem_name,
        current_version,
        source_type,
        "Skipping comparison for #{gem_name}: unsupported source #{source_type}"
      )
    end

    remote = spec.source&.remotes&.first&.host
    unless remote
      return metadata_missing_info(
        gem_name,
        current_version,
        :metadata_unavailable,
        "Skipping comparison for #{gem_name}: no remote URI available"
      )
    end

    versions = @gem_fetcher.fetch_gem_versions(gem_name, remote_host: remote)
    unless versions&.any?
      return metadata_missing_info(
        gem_name,
        current_version,
        :metadata_unavailable,
        "Skipping comparison for #{gem_name}: no version metadata returned from #{remote}"
      )
    end

    versions_within_as_of = filter_versions_by_date(versions, as_of)

    if as_of && versions_within_as_of.empty?
      return metadata_missing_info(
        gem_name,
        current_version,
        :latest_version_unavailable_for_date,
        "Skipping comparison for #{gem_name}: no release available on or before #{as_of.iso8601}"
      )
    end

    latest_version_info = versions_within_as_of.first || versions.first
    latest_version = latest_version_info["number"]
    latest_release_date = safe_parse_date(latest_version_info["created_at"])

    version_distance = versions_within_as_of.index { |version| version["number"] == current_version }

    unless version_distance
      current_version_metadata = versions.find { |version| version["number"] == current_version }
      unless current_version_metadata
        return metadata_missing_info(
          gem_name,
          current_version,
          :current_version_missing,
          "Skipping comparison for #{gem_name}: installed version #{current_version} missing from metadata"
        )
      end

      current_release_date = safe_parse_date(current_version_metadata["created_at"])
      unless current_release_date
        return metadata_missing_info(
          gem_name,
          current_version,
          :release_date_missing,
          "Skipping comparison for #{gem_name}: missing release date for installed version"
        )
      end

      if as_of && current_release_date > as_of
        return metadata_missing_info(
          gem_name,
          current_version,
          :current_version_unreleased_for_date,
          "Skipping comparison for #{gem_name}: installed version newer than as-of date"
        )
      end

      return metadata_missing_info(
        gem_name,
        current_version,
        :current_version_missing,
        "Skipping comparison for #{gem_name}: installed version #{current_version} missing from metadata"
      )
    end

    current_version_info = versions_within_as_of[version_distance]
    current_release_date = safe_parse_date(current_version_info["created_at"])

    unless latest_release_date && current_release_date
      return metadata_missing_info(
        gem_name,
        current_version,
        :release_date_missing,
        "Skipping comparison for #{gem_name}: release date data is incomplete"
      )
    end

    libyear_in_days = [(latest_release_date - current_release_date).to_i, 0].max

    GemInfo.new(
      name: gem_name,
      current_version: current_version,
      latest_version: latest_version,
      version_distance: version_distance,
      is_direct: true,
      libyear_in_days: libyear_in_days,
      status: :ok
    )
  rescue Date::Error => e
    metadata_missing_info(
      gem_name,
      current_version,
      :invalid_release_date,
      "Skipping comparison for #{gem_name}: #{e.message}"
    )
  end

  def filter_versions_by_date(versions, as_of)
    return versions unless as_of

    versions.select do |version|
      created_at = version["created_at"]
      next false unless created_at

      date = safe_parse_date(created_at)
      date && date <= as_of
    end
  end

  def unresolved_source_info(gem_name, current_version, source_type, message)
    default_reason = case source_type
    when :git
      "Git-sourced gems lack remote metadata for comparison"
    when :path
      "Path-sourced gems lack remote metadata for comparison"
    when :unknown
      "Dependency source is unknown or unsupported"
    else
      "Dependency source cannot be resolved"
    end
    log_message = message || default_reason
    @logger.warn(log_message)

    GemInfo.new(
      name: gem_name,
      current_version: current_version,
      latest_version: nil,
      version_distance: nil,
      is_direct: true,
      libyear_in_days: nil,
      status: :unresolvable_source
    )
  end

  def metadata_missing_info(gem_name, current_version, status, message)
    @logger.warn(message) if message

    GemInfo.new(
      name: gem_name,
      current_version: current_version,
      latest_version: nil,
      version_distance: nil,
      is_direct: true,
      libyear_in_days: nil,
      status: status
    )
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

  def remote_uri_for(spec)
    source = spec.source
    return nil unless source.respond_to?(:remotes)

    remote = source.remotes.find { |uri| uri }
    remote&.to_s
  end

  def safe_parse_date(value)
    return nil if value.nil?

    Date.parse(value)
  rescue Date::Error
    nil
  end
end
