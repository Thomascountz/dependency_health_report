require "date"

class DependencyAnalyzer
  RISK_THRESHOLDS = {
    low: 10,
    moderate: 16,
    high: 22
  }

  RATING_THRESHOLDS = {
    5 => {moderate: 8.3, high: 0, very_high: 0},
    4 => {moderate: 30.4, high: 14.3, very_high: 7.7},
    3 => {moderate: 38.9, high: 30.6, very_high: 19.7},
    2 => {moderate: 60.0, high: 46.3, very_high: 27.8}
  }

  def initialize(gem_fetcher)
    @gem_fetcher = gem_fetcher
  end

  def calculate_dependency_freshness(lockfile, direct_dependencies)
    freshness = {}
    cumulative_libyear_in_days = 0

    lockfile.specs.each do |spec|
      gem_name = spec.name
      current_version = spec.version.to_s
      is_direct = direct_dependencies.include?(gem_name)

      next unless is_direct

      versions = @gem_fetcher.fetch_gem_versions(gem_name)
      latest_version = versions.first["number"]
      version_distance = versions.index { |v| v["number"] == current_version }

      current_version_info = versions.find { |v| v["number"] == current_version }

      next unless current_version_info

      current_release_date = Date.parse(current_version_info["created_at"])
      next_release_date_str = versions[version_distance - 1]&.fetch("created_at", nil) if version_distance.positive?
      next_release_date = Date.parse(next_release_date_str) if next_release_date_str
      age_in_days = (next_release_date - current_release_date).to_i if next_release_date

      freshness[gem_name] = GemInfo.new(
        name: gem_name,
        current_version: current_version,
        latest_version: latest_version,
        version_distance: version_distance,
        is_direct: true,
        age_in_days: age_in_days
      )

      cumulative_libyear_in_days += age_in_days if age_in_days
    end

    [freshness, cumulative_libyear_in_days]
  end

  def categorize_risks(dependency_freshness)
    risk_profile = {low: 0, moderate: 0, high: 0, very_high: 0}

    dependency_freshness.each_value do |data|
      category = risk_category_from_distance(data.version_distance)
      risk_profile[category] += 1
    end

    risk_profile
  end

  def calculate_cumulative_risk_profile(risk_profile, total_dependencies)
    cumulative_risk_profile = {}
    cumulative_risk_profile[:very_high] = risk_profile[:very_high].to_f / total_dependencies * 100
    cumulative_risk_profile[:high] = (risk_profile[:high] + risk_profile[:very_high]).to_f / total_dependencies * 100
    cumulative_risk_profile[:moderate] = (risk_profile[:moderate] + risk_profile[:high] + risk_profile[:very_high]).to_f / total_dependencies * 100
    cumulative_risk_profile
  end

  def determine_rating(cumulative_risk_profile)
    rating = 1
    RATING_THRESHOLDS.keys.sort.reverse_each do |candidate_rating|
      thresholds = RATING_THRESHOLDS[candidate_rating]
      if cumulative_risk_profile[:moderate] <= thresholds[:moderate] &&
          cumulative_risk_profile[:high] <= thresholds[:high] &&
          cumulative_risk_profile[:very_high] <= thresholds[:very_high]
        rating = candidate_rating
        break
      end
    end
    rating
  end

  private

  def risk_category_from_distance(version_distance)
    case version_distance
    when 0...RISK_THRESHOLDS[:low]
      :low
    when RISK_THRESHOLDS[:low]...RISK_THRESHOLDS[:moderate]
      :moderate
    when RISK_THRESHOLDS[:moderate]...RISK_THRESHOLDS[:high]
      :high
    else
      :very_high
    end
  end
end
