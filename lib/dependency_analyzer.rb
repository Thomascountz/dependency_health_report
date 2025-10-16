require "bundler"
require "date"

class DependencyAnalyzer
  def initialize(gem_fetcher)
    @gem_fetcher = gem_fetcher
  end

  def calculate_dependency_freshness(lockfile, direct_dependencies, as_of: nil)
    freshness = {}

    lockfile.specs.each do |spec|
      gem_name = spec.name
      next unless direct_dependencies.include?(gem_name)

      info = build_gem_info(spec, as_of: as_of)
      freshness[gem_name] = info if info
    end

    freshness
  end

  private

  def build_gem_info(spec, as_of:)
    gem_name = spec.name
    current_version = spec.version&.to_s
    source_type = source_type_for(spec)

    return unresolved_source_info(gem_name, current_version, source_type) unless source_type == :rubygems

    remote = remote_uri_for(spec)
    return unresolved_source_info(gem_name, current_version, source_type, "No remote URI associated with dependency source") unless remote

    versions = @gem_fetcher.fetch_gem_versions(gem_name, remote: remote)
    return metadata_missing_info(gem_name, current_version, :metadata_unavailable, "No version metadata returned from #{remote}") unless versions&.any?

    versions_within_as_of =
      if as_of
        versions.select do |version|
          created_at = version["created_at"]
          next false unless created_at

          Date.parse(created_at) <= as_of
        rescue Date::Error
          false
        end
      else
        versions
      end

    if as_of && versions_within_as_of.empty?
      return metadata_missing_info(
        gem_name,
        current_version,
        :latest_version_unavailable_for_date,
        "No release of #{gem_name} was available on or before #{as_of.iso8601}"
      )
    end

    latest_version_info = versions_within_as_of.first || versions.first
    latest_version = latest_version_info["number"]
    latest_release_date_str = latest_version_info["created_at"]

    versions_for_distance = versions_within_as_of
    version_distance = versions_for_distance.index { |version| version["number"] == current_version }

    if version_distance.nil?
      current_version_metadata = versions.find { |version| version["number"] == current_version }

      unless current_version_metadata
        return metadata_missing_info(
          gem_name,
          current_version,
          :current_version_missing,
          "Installed version #{current_version} not found in metadata from #{remote}"
        )
      end

      current_release_date_str = current_version_metadata["created_at"]
      if current_release_date_str.nil?
        return metadata_missing_info(
          gem_name,
          current_version,
          :release_date_missing,
          "Release date data is incomplete for #{gem_name} at #{remote}"
        )
      end

      begin
        current_release_date = Date.parse(current_release_date_str)
      rescue Date::Error
        return metadata_missing_info(
          gem_name,
          current_version,
          :invalid_release_date,
          "Release dates for #{gem_name} could not be parsed"
        )
      end

      if as_of && current_release_date > as_of
        return metadata_missing_info(
          gem_name,
          current_version,
          :current_version_unreleased_for_date,
          "Installed version #{current_version} released on #{current_release_date.iso8601} is newer than the as-of date #{as_of.iso8601}"
        )
      end

      return metadata_missing_info(
        gem_name,
        current_version,
        :current_version_missing,
        "Installed version #{current_version} not found in metadata from #{remote}"
      )
    end

    current_version_info = versions_for_distance[version_distance]
    current_release_date_str = current_version_info["created_at"]

    if latest_release_date_str.nil? || current_release_date_str.nil?
      return metadata_missing_info(
        gem_name,
        current_version,
        :release_date_missing,
        "Release date data is incomplete for #{gem_name} at #{remote}"
      )
    end

    latest_release_date = Date.parse(latest_release_date_str)
    current_release_date = Date.parse(current_release_date_str)
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
  rescue Date::Error
    metadata_missing_info(
      gem_name,
      current_version,
      :invalid_release_date,
      "Release dates for #{gem_name} could not be parsed"
    )
  end

  def unresolved_source_info(gem_name, current_version, source_type, message = nil)
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

    GemInfo.new(
      name: gem_name,
      current_version: current_version,
      latest_version: nil,
      version_distance: nil,
      is_direct: true,
      libyear_in_days: nil,
      status: :unresolvable_source,
      status_message: message || default_reason
    )
  end

  def metadata_missing_info(gem_name, current_version, status, message)
    GemInfo.new(
      name: gem_name,
      current_version: current_version,
      latest_version: nil,
      version_distance: nil,
      is_direct: true,
      libyear_in_days: nil,
      status: status,
      status_message: message
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
    return nil unless source && source.respond_to?(:remotes)

    remote = source.remotes.find { |uri| uri }
    remote&.to_s
  end
end
