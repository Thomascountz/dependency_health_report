class GemInfo
  attr_reader :name,
              :current_version,
              :latest_version,
              :version_distance,
              :is_direct,
              :libyear_in_days,
              :status,
              :status_message

  def initialize(
    name:,
    current_version:,
    latest_version:,
    version_distance:,
    is_direct:,
    libyear_in_days:,
    status: :ok,
    status_message: nil
  )
    @name = name
    @current_version = current_version
    @latest_version = latest_version
    @version_distance = version_distance
    @is_direct = is_direct
    @libyear_in_days = libyear_in_days
    @status = status
    @status_message = status_message
  end

  def ok?
    status == :ok
  end
end
