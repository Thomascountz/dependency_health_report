# frozen_string_literal: true

require_relative "test_helper"
require "stringio"

class PlaintextReporterTest < Minitest::Test
  def test_generates_report_with_single_result
    output = StringIO.new
    reporter = PlaintextReporter.new(io: output)
    results = [
      outdated_gem_result(
        name: "rails",
        current_version: "6.0.0",
        latest_version: "7.0.0",
        version_distance: 2,
        libyear_in_days: 365
      )
    ]

    reporter.generate(results)

    output_lines = output.string.lines
    assert_includes output_lines[0], "Gem"
    assert_includes output_lines[0], "Current"
    assert_includes output_lines[0], "Latest"
    assert_includes output_lines[2], "rails"
    assert_includes output_lines[2], "6.0.0"
    assert_includes output_lines[2], "7.0.0"

    assert_includes output_lines[3], "System is 1.00 libyears behind"
    assert_includes output_lines[4], "Total releases behind: 2"
  end

  def test_generates_report_with_multiple_results_sorted_by_name
    output = StringIO.new
    reporter = PlaintextReporter.new(io: output)
    results = [
      outdated_gem_result(name: "zebra", version_distance: 1),
      outdated_gem_result(name: "alpha", version_distance: 1),
      outdated_gem_result(name: "beta", version_distance: 1)
    ]

    reporter.generate(results)

    output_text = output.string
    alpha_position = output_text.index("alpha")
    beta_position = output_text.index("beta")
    zebra_position = output_text.index("zebra")

    assert alpha_position < beta_position
    assert beta_position < zebra_position
  end

  def test_excludes_up_to_date_gems_from_report
    output = StringIO.new
    reporter = PlaintextReporter.new(io: output)
    results = [
      outdated_gem_result(name: "outdated-gem", version_distance: 5),
      outdated_gem_result(name: "up-to-date-gem", version_distance: 0)
    ]

    reporter.generate(results)

    output_text = output.string
    assert_includes output_text, "outdated-gem"
    refute_includes output_text, "up-to-date-gem"
  end

  def test_formats_dates_correctly
    output = StringIO.new
    reporter = PlaintextReporter.new(io: output)
    results = [
      outdated_gem_result(
        current_version_release_date: Date.new(2021, 3, 15),
        latest_version_release_date: Date.new(2023, 12, 25),
        version_distance: 1
      )
    ]

    reporter.generate(results)

    output_text = output.string
    assert_includes output_text, "2021-03-15"
    assert_includes output_text, "2023-12-25"
  end

  def test_includes_all_column_headers
    output = StringIO.new
    reporter = PlaintextReporter.new(io: output)
    results = [outdated_gem_result(version_distance: 1)]

    reporter.generate(results)

    header_line = output.string.lines.first
    assert_includes header_line, "Gem"
    assert_includes header_line, "Current"
    assert_includes header_line, "Current Date"
    assert_includes header_line, "Latest"
    assert_includes header_line, "Latest Date"
    assert_includes header_line, "Versions"
    assert_includes header_line, "Days"
    assert_includes header_line, "Years"
  end

  def test_includes_divider_line_after_headers
    output = StringIO.new
    reporter = PlaintextReporter.new(io: output)
    results = [outdated_gem_result(version_distance: 1)]

    reporter.generate(results)

    lines = output.string.lines
    divider_line = lines[1]
    assert_match(/^\.+/, divider_line, "Second line should be a divider of dots")
  end

  def test_calculates_years_from_days
    output = StringIO.new
    reporter = PlaintextReporter.new(io: output)
    results = [
      outdated_gem_result(
        libyear_in_days: 712,
        version_distance: 1
      )
    ]

    reporter.generate(results)

    output_text = output.string
    # 712 / 365.0 = 1.95
    assert_includes output_text, " 1.95\n"
  end

  def test_handles_empty_results
    output = StringIO.new
    reporter = PlaintextReporter.new(io: output)
    results = []

    reporter.generate(results)

    assert_equal "", output.string
  end

  def test_right_aligns_numeric_columns
    output = StringIO.new
    reporter = PlaintextReporter.new(io: output)
    results = [
      outdated_gem_result(
        name: "a",
        version_distance: 5,
        libyear_in_days: 100
      ),
      outdated_gem_result(
        name: "b",
        version_distance: 500,
        libyear_in_days: 10000
      )
    ]

    reporter.generate(results)

    lines = output.string.lines
    data_line_1 = lines[2]
    data_line_2 = lines[3]

    # The version distance column should be right-aligned
    # Find the "Versions" column position from header
    header = lines[0]
    versions_col_end = header.index("Days") - 1

    # Extract the versions column values
    version_1 = data_line_1[0...versions_col_end].strip.split.last
    version_2 = data_line_2[0...versions_col_end].strip.split.last

    assert_equal "5", version_1
    assert_equal "500", version_2
  end

  private

  # Parameterized Creation Method: Provides sensible defaults for all fields
  # while allowing tests to override only the relevant values
  def outdated_gem_result(
    name: "test-gem",
    current_version: "1.9.0",
    current_version_release_date: Date.new(2020, 1, 1),
    latest_version: "2.0.0",
    latest_version_release_date: Date.new(2021, 1, 1),
    version_distance: 1,
    libyear_in_days: 365
  )
    Result.new(
      name: name,
      current_version: current_version,
      current_version_release_date: current_version_release_date,
      latest_version: latest_version,
      latest_version_release_date: latest_version_release_date,
      version_distance: version_distance,
      is_direct: true,
      libyear_in_days: libyear_in_days
    )
  end
end
