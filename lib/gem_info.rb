class GemInfo
  attr_reader :name, :current_version, :latest_version, :version_distance, :is_direct, :age_in_days

  def initialize(name:, current_version:, latest_version:, version_distance:, is_direct:, age_in_days:)
    @name = name
    @current_version = current_version
    @latest_version = latest_version
    @version_distance = version_distance
    @is_direct = is_direct
    @age_in_days = age_in_days
  end
end
