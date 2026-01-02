# frozen_string_literal: true

require_relative "reporter"

class PlaintextReporter < Reporter
  COLUMN_DEFINITIONS = [
    {header: "Gem", alignment: :left, value: ->(result) { result.name.to_s }},
    {header: "Current", alignment: :left, value: ->(result) { value_or_unknown(result.current_version) }},
    {header: "Current Date", alignment: :left, value: ->(result) { format_date(result.current_version_release_date) }},
    {header: "Latest", alignment: :left, value: ->(result) { value_or_unknown(result.latest_version) }},
    {header: "Latest Date", alignment: :left, value: ->(result) { format_date(result.latest_version_release_date) }},
    {header: "Versions", alignment: :right, value: ->(result) { numeric_or_unknown(result.version_distance) }},
    {header: "Days", alignment: :right, value: ->(result) { numeric_or_unknown(result.libyear_in_days) }},
    {header: "Years", alignment: :right, value: ->(result) { float_or_unknown(result.libyear_in_days / 365.0) }}
  ].freeze

  def initialize(io: $stdout)
    @io = io
  end

  def generate(results)
    rows = build_rows(results)
    return if rows.empty?

    table_lines(rows).each { |line| @io.puts(line) }
  end

  private

  def build_rows(results)
    results.each.sort_by(&:name).each_with_object([]) do |data, rows|
      next if data.version_distance.zero?

      rows << COLUMN_DEFINITIONS.map { |column| instance_exec(data, &column[:value]) }
    end
  end

  def table_lines(rows)
    widths = column_widths(rows)
    headers = COLUMN_DEFINITIONS.map { |column| column[:header] }

    [format_line(headers, widths), divider(widths), *rows.map { |row| format_line(row, widths) }]
  end

  def divider(widths)
    widths.map { |width| "." * width }.join(" ")
  end

  def column_widths(rows)
    COLUMN_DEFINITIONS.each_index.map do |index|
      column_values = rows.map { |row| row[index] }
      ([COLUMN_DEFINITIONS[index][:header]] + column_values).map(&:length).max
    end
  end

  def format_line(values, widths)
    values.each_with_index.map do |value, index|
      aligned(value, widths[index], COLUMN_DEFINITIONS[index][:alignment])
    end.join(" ")
  end

  def aligned(value, width, alignment)
    (alignment == :right) ? value.rjust(width) : value.ljust(width)
  end

  def value_or_unknown(value)
    value.nil? ? "Unknown" : value.to_s
  end

  def numeric_or_unknown(value)
    value.nil? ? "Unknown" : value.to_s
  end

  def float_or_unknown(value, precision: 2)
    value.nil? ? "Unknown" : ("%.#{precision}f" % value)
  end

  def format_date(value)
    return "Unknown" if value.nil?
    return value.strftime("%Y-%m-%d") if value.respond_to?(:strftime)

    value.to_s
  end
end
