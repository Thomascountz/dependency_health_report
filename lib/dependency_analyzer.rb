require "date"

class DependencyAnalyzer
  def initialize(gem_fetcher)
    @gem_fetcher = gem_fetcher
  end

  def calculate_dependency_freshness(lockfile, direct_dependencies)
    freshness = {}

    lockfile.specs.each do |spec|
      gem_name = spec.name
      current_version = spec.version.to_s

      next unless direct_dependencies.include?(gem_name)

      remote = remote_uri_for(spec)
      next unless remote

      versions = @gem_fetcher.fetch_gem_versions(gem_name, remote: remote)
      next unless versions&.any?

      latest_version = versions.first["number"]
      version_distance = versions.index { |version| version["number"] == current_version }

      next unless version_distance

      current_version_info = versions[version_distance]
      current_release_date_str = current_version_info["created_at"]

      next unless current_release_date_str

      current_release_date = Date.parse(current_release_date_str)
      next_release_date_str = version_distance.positive? ? versions[version_distance - 1]&.fetch("created_at", nil) : nil
      next_release_date = Date.parse(next_release_date_str) if next_release_date_str
      age_in_days = next_release_date ? (next_release_date - current_release_date).to_i : 0

      freshness[gem_name] = GemInfo.new(
        name: gem_name,
        current_version: current_version,
        latest_version: latest_version,
        version_distance: version_distance,
        is_direct: true,
        age_in_days: age_in_days
      )
    end

    freshness
  end

  private

  def remote_uri_for(spec)
    source = spec.source
    return nil unless source && source.respond_to?(:remotes)

    remote = source.remotes.find { |uri| uri }
    remote&.to_s
  end
end
