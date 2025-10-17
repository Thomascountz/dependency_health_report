# frozen_string_literal: true

class GemInfo
  attr_reader :name,
    :current_version,
    :latest_version,
    :version_distance,
    :is_direct,
    :libyear_in_days,
    :status

  def initialize(
    name:,
    current_version:,
    latest_version:,
    version_distance:,
    is_direct:,
    libyear_in_days:,
    status: :ok
  )
    @name = name
    @current_version = current_version
    @latest_version = latest_version
    @version_distance = version_distance
    @is_direct = is_direct
    @libyear_in_days = libyear_in_days
    @status = status
  end

  def ok?
    status == :ok
  end
end
