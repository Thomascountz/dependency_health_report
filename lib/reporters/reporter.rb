class Reporter
  def initialize
    @risk_thresholds = {
      low: 10,
      moderate: 16,
      high: 22
    }
  end

  def generate(dependency_freshness, cumulative_risk_profile, rating, cumulative_libyear_in_days)
    raise NotImplementedError, "Subclasses must implement the generate method"
  end

  protected

  def risk_category_from_distance(version_distance)
    case version_distance
    when 0...@risk_thresholds[:low]
      :low
    when @risk_thresholds[:low]...@risk_thresholds[:moderate]
      :moderate
    when @risk_thresholds[:moderate]...@risk_thresholds[:high]
      :high
    else
      :very_high
    end
  end

  def action_for_category(category)
    case category
    when :low
      "No immediate actions required."
    when :moderate
      "Upgrading is recommended soon."
    when :high
      "Upgrading is recommended ASAP."
    else
      "Immediate upgrade is required."
    end
  end
end
