# frozen_string_literal: true

require_relative "test_helper"

class DependencyAnalyzerTest < Minitest::Test
  def test_calculates_version_distance_for_outdated_gem
    # Setup
    analyzer = DependencyAnalyzer.new(logger: Logger.new(nil))
    gem_name = "rails"
    current_version = Gem::Version.new("6.0.0")
    versions_metadata = [
      gem_version(number: "7.0.0", created_at: Date.new(2023, 1, 1)),
      gem_version(number: "6.1.0", created_at: Date.new(2022, 1, 1)),
      gem_version(number: "6.0.0", created_at: Date.new(2021, 1, 1))
    ]

    result = analyzer.calculate_dependency_freshness(gem_name, current_version, versions_metadata)

    assert_equal 2, result.version_distance
  end

  def test_calculates_libyear_in_days_for_outdated_gem
    # Setup
    analyzer = DependencyAnalyzer.new(logger: Logger.new(nil))
    gem_name = "rails"
    current_version = Gem::Version.new("6.0.0")
    current_date = Date.new(2021, 1, 1)
    latest_date = Date.new(2023, 1, 1)
    versions_metadata = [
      gem_version(number: "7.0.0", created_at: latest_date),
      gem_version(number: "6.0.0", created_at: current_date)
    ]

    result = analyzer.calculate_dependency_freshness(gem_name, current_version, versions_metadata)

    assert_equal 730, result.libyear_in_days
  end

  def test_returns_nil_when_gem_is_up_to_date
    # Setup
    analyzer = DependencyAnalyzer.new(logger: Logger.new(nil))
    gem_name = "rails"
    current_version = Gem::Version.new("7.0.0")
    versions_metadata = [
      gem_version(number: "7.0.0", created_at: Date.new(2023, 1, 1))
    ]

    result = analyzer.calculate_dependency_freshness(gem_name, current_version, versions_metadata)

    assert_nil result
  end

  def test_returns_nil_when_current_version_not_in_metadata
    # Setup
    analyzer = DependencyAnalyzer.new(logger: Logger.new(nil))
    gem_name = "rails"
    current_version = Gem::Version.new("5.0.0")
    versions_metadata = [
      gem_version(number: "7.0.0", created_at: Date.new(2023, 1, 1)),
      gem_version(number: "6.0.0", created_at: Date.new(2021, 1, 1))
    ]

    result = analyzer.calculate_dependency_freshness(gem_name, current_version, versions_metadata)

    assert_nil result
  end

  def test_handles_prerelease_current_version
    # Setup
    analyzer = DependencyAnalyzer.new(logger: Logger.new(nil))
    gem_name = "rails"
    current_version = Gem::Version.new("7.0.0.rc1")
    versions_metadata = [
      gem_version(number: "7.0.0", created_at: Date.new(2023, 2, 1), prerelease: false),
      gem_version(number: "7.0.0.rc1", created_at: Date.new(2023, 1, 15), prerelease: true),
      gem_version(number: "6.1.0", created_at: Date.new(2022, 1, 1), prerelease: false)
    ]

    result = analyzer.calculate_dependency_freshness(gem_name, current_version, versions_metadata)

    refute_nil result
    assert_equal "7.0.0", result.latest_version.to_s
  end

  def test_skips_prerelease_versions_for_stable_current_version
    # Setup
    analyzer = DependencyAnalyzer.new(logger: Logger.new(nil))
    gem_name = "rails"
    current_version = Gem::Version.new("6.0.0")
    versions_metadata = [
      gem_version(number: "7.0.0.rc1", created_at: Date.new(2023, 2, 1), prerelease: true),
      gem_version(number: "6.1.0", created_at: Date.new(2022, 1, 1), prerelease: false),
      gem_version(number: "6.0.0", created_at: Date.new(2021, 1, 1), prerelease: false)
    ]

    result = analyzer.calculate_dependency_freshness(gem_name, current_version, versions_metadata)

    refute_nil result
    assert_equal "6.1.0", result.latest_version.to_s
  end

  def test_ensures_libyear_is_never_negative
    # Setup
    analyzer = DependencyAnalyzer.new(logger: Logger.new(nil))
    gem_name = "rails"
    current_version = Gem::Version.new("6.0.0")
    # Edge case: latest version has earlier date than current
    versions_metadata = [
      gem_version(number: "6.1.0", created_at: Date.new(2020, 1, 1)),
      gem_version(number: "6.0.0", created_at: Date.new(2021, 1, 1))
    ]

    result = analyzer.calculate_dependency_freshness(gem_name, current_version, versions_metadata)

    assert_equal 0, result.libyear_in_days
  end

  def test_populates_result_with_all_required_fields
    # Setup
    analyzer = DependencyAnalyzer.new(logger: Logger.new(nil))
    gem_name = "rails"
    current_version = Gem::Version.new("6.0.0")
    current_date = Date.new(2021, 1, 1)
    latest_date = Date.new(2023, 1, 1)
    versions_metadata = [
      gem_version(number: "7.0.0", created_at: latest_date),
      gem_version(number: "6.1.0", created_at: Date.new(2022, 1, 1)),
      gem_version(number: "6.0.0", created_at: current_date)
    ]

    result = analyzer.calculate_dependency_freshness(gem_name, current_version, versions_metadata)

    assert_equal "rails", result.name
    assert_equal current_version, result.current_version
    assert_equal current_date, result.current_version_release_date
    assert_equal Gem::Version.new("7.0.0"), result.latest_version
    assert_equal latest_date, result.latest_version_release_date
    assert_equal 2, result.version_distance
    assert_equal 730, result.libyear_in_days
    assert result.is_direct
  end

  private

  # Parameterized Creation Method: Hides essential but irrelevant setup details
  # while keeping test-specific values visible in each test
  def gem_version(number:, created_at:, prerelease: false)
    GemVersion.new(
      name: "test-gem",
      number: Gem::Version.new(number),
      created_at: created_at,
      prerelease?: prerelease
    )
  end
end
