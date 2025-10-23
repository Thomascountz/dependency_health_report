# frozen_string_literal: true

require "rubygems"

# Helper module for parsing semantic versions using Gem::Version
module SemverParser
  # Parse a version string into semantic version components
  # @param version_string [String] The version string to parse
  # @return [Hash] A hash containing the parsed components
  def self.parse(version_string)
    return empty_components if version_string.nil? || version_string.empty?

    # Extract build metadata first (Gem::Version doesn't handle + well)
    clean_version = version_string
    build_metadata = nil
    if version_string =~ /^(.+?)\+(.+)$/
      clean_version = $1
      build_metadata = $2
    end

    begin
      gem_version = Gem::Version.new(clean_version)
      segments = gem_version.segments

      # Extract base version components
      major = segments[0] || 0
      minor = segments[1] || 0
      patch = segments[2] || 0

      # Detect prerelease info
      prerelease_info = extract_prerelease_info(clean_version, gem_version)

      {
        major: major.is_a?(Integer) ? major : 0,
        minor: minor.is_a?(Integer) ? minor : 0,
        patch: patch.is_a?(Integer) ? patch : 0,
        prerelease_type: prerelease_info[:type],
        prerelease_number: prerelease_info[:number],
        build_metadata: build_metadata
      }
    rescue ArgumentError => e
      # If Gem::Version can't parse it, return empty components
      empty_components.merge(parse_error: e.message)
    end
  end

  def self.empty_components
    {
      major: 0,
      minor: 0,
      patch: 0,
      prerelease_type: nil,
      prerelease_number: nil,
      build_metadata: nil
    }
  end

  def self.extract_prerelease_info(version_string, gem_version)
    return {type: nil, number: nil} unless gem_version.prerelease?

    # Common prerelease patterns
    if version_string =~ /\.(alpha|beta|rc|pre)\.?(\d*)/i
      type = $1.downcase
      number = $2.empty? ? nil : $2.to_i
      return {type: type, number: number}
    end

    # Handle cases like "1.0.0.pre" without number
    if version_string =~ /\.(alpha|beta|rc|pre)$/i
      return {type: $1.downcase, number: nil}
    end

    # Generic prerelease (any non-numeric segment)
    # This handles cases like "1.0.0.preview1" or custom prerelease identifiers
    segments = version_string.split(".")
    segments.each_with_index do |segment, idx|
      next if idx < 3 # Skip major.minor.patch

      if segment =~ /^([a-zA-Z]+)(\d*)$/
        type = $1.downcase
        number = $2.empty? ? nil : $2.to_i
        return {type: type, number: number}
      end
    end

    # If we can't identify the type, just mark it as prerelease
    {type: "pre", number: nil}
  end

  # Convenience method to check if a version would sort before another
  # using semver rules (useful for validation)
  def self.compare(version_a, version_b)
    Gem::Version.new(version_a) <=> Gem::Version.new(version_b)
  rescue ArgumentError
    nil
  end
end
