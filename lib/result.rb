# frozen_string_literal: true

Result = Data.define(
  :name,
  :current_version,
  :current_version_release_date,
  :latest_version,
  :latest_version_release_date,
  :version_distance,
  :is_direct,
  :libyear_in_days,
  :status
)
