# frozen_string_literal: true

require "base64"
require "json"
require "fileutils"

require_relative "models"
require_relative "structured_logger"

class LockfileParser
  class CacheMissError < StandardError; end

  # Section markers
  BUNDLED_WITH = /^BUNDLED WITH$/
  CHECKSUMS = /^CHECKSUMS$/
  DEPENDENCIES = /^DEPENDENCIES$/
  GEM = /^GEM$/
  GIT = /^GIT$/
  PATH = /^PATH$/
  PLATFORMS = /^PLATFORMS$/
  PLUGIN = /^PLUGIN SOURCE$/
  RUBY = /^RUBY VERSION$/

  # Entry patterns
  REMOTE = /^  remote: (.+)$/
  REVISION = /^  revision: (.+)$/
  SPECS = /^  specs:$/
  OPTION = /^  ([a-z]+): (.+)$/i
  SPEC_ENTRY = /^    ([^ (]+)(?: \(([^)]+)\))?$/
  DEPENDENCY_ENTRY = /^      ([^ (]+)(?: \(([^)]+)\))?$/
  TOP_LEVEL_DEPENDENCY = /^  ([^ (]+)(?: \(([^)]+)\))?(!)?$/
  PLATFORM_ENTRY = /^  (.+)$/
  VERSION_LINE = /^   (.+)$/
  BUNDLED_VERSION = /^   (.+)$/

  # Pattern to match platform suffixes in version strings
  PLATFORM_PATTERN = /-([a-z0-9_-]+)$/

  LOCKFILE_CACHE_DIR = File.join(".cache", "lockfiles")

  def initialize(logger: StructuredLogger.new($stderr))
    @logger = logger
  end

  def parse(lockfile_content, cache_metadata: nil)
    lockfile_content = prepare_lockfile_content(lockfile_content, cache_metadata)

    if lockfile_content.nil?
      raise CacheMissError, "Lockfile content was nil and no cache available"
    end

    lines = lockfile_content.lines.map(&:chomp)

    sources = []
    platforms = []
    dependencies = []
    ruby_version = nil
    bundled_with = nil

    i = 0
    while i < lines.length
      line = lines[i]

      case line
      when GIT, GEM, PATH, PLUGIN
        source, next_i = parse_source(lines, i)
        sources << source
        i = next_i
      when PLATFORMS
        platforms, i = parse_platforms(lines, i + 1)
      when DEPENDENCIES
        dependencies, i = parse_dependencies(lines, i + 1)
      when RUBY
        ruby_version, i = parse_ruby_version(lines, i + 1)
      when BUNDLED_WITH
        bundled_with, i = parse_bundled_with(lines, i + 1)
      when CHECKSUMS
        i = skip_section(lines, i + 1)
      else
        i += 1
      end
    end

    Lockfile.new(
      sources: sources,
      platforms: platforms,
      dependencies: dependencies,
      ruby_version: ruby_version,
      bundled_with: bundled_with
    )
  end

  private

  def prepare_lockfile_content(lockfile_content, cache_metadata)
    return lockfile_content if cache_metadata.nil?
    return lockfile_content if cache_disabled? && !lockfile_content.nil?

    if lockfile_content.nil?
      return read_lockfile_cache(cache_metadata)
    end

    write_lockfile_cache(lockfile_content, cache_metadata)
    lockfile_content
  end

  def cache_disabled?
    ENV["SKIP_CACHE"] == "1"
  end

  def write_lockfile_cache(lockfile_content, cache_metadata)
    cache_file = cache_path(cache_metadata)

    FileUtils.mkdir_p(File.dirname(cache_file))

    payload = {
      "base64" => Base64.strict_encode64(lockfile_content),
      "commit_sha" => cache_metadata[:commit_sha],
      "remote_url" => cache_metadata[:remote_url]
    }

    File.write(cache_file, JSON.dump(payload))
  rescue SystemCallError => e
    @logger&.warn("Failed to write lockfile cache: #{e.message}")
    lockfile_content
  end

  def read_lockfile_cache(cache_metadata)
    raise CacheMissError, "Lockfile cache disabled" if cache_disabled?

    cache_file = cache_path(cache_metadata)

    unless File.exist?(cache_file)
      raise CacheMissError, "Lockfile cache not found at #{cache_file}"
    end

    payload = JSON.parse(File.read(cache_file))
    Base64.decode64(payload.fetch("base64"))
  rescue JSON::ParserError => e
    raise CacheMissError, "Lockfile cache corrupt at #{cache_file}: #{e.message}"
  end

  def cache_path(cache_metadata)
    if cache_metadata[:cache_key]
      sanitized_key = sanitize_segment(cache_metadata[:cache_key])
      return File.join(LOCKFILE_CACHE_DIR, "by_key", "#{sanitized_key}.json")
    end

    remote_segments = cache_remote_segments(cache_metadata[:remote_url])
    commit_segment = sanitize_segment(cache_metadata[:commit_sha] || "current")

    File.join(LOCKFILE_CACHE_DIR, *remote_segments, "#{commit_segment}.json")
  end

  def cache_remote_segments(remote_url)
    return ["unknown"] if remote_url.nil? || remote_url.strip.empty?

    sanitized = remote_url.strip.sub(/\.git\z/, "")
    segments = sanitized.split(/[\/\:]/).reject(&:empty?).map { |segment| sanitize_segment(segment) }
    segments.empty? ? ["unknown"] : segments
  end

  def sanitize_segment(segment)
    segment.to_s.gsub(/[^a-zA-Z0-9._-]/, "_")
  end

  def parse_source(lines, start_idx)
    type = case lines[start_idx]
    when GIT then :git
    when GEM then :gem
    when PATH then :path
    when PLUGIN then :plugin
    end

    remote = nil
    revision = nil
    specs = []
    options = {}

    i = start_idx + 1
    while i < lines.length && !section_header?(lines[i])
      line = lines[i]

      case line
      when REMOTE
        remote = line.match(REMOTE)[1]
      when REVISION
        revision = line.match(REVISION)[1]
      when SPECS
        specs, i = parse_specs(lines, i + 1)
        next
      when OPTION
        match = line.match(OPTION)
        options[match[1]] = match[2]
      end

      i += 1
    end

    source = Source.new(
      type: type,
      remote: remote,
      revision: revision,
      specs: specs,
      options: options
    )

    [source, i]
  end

  def parse_specs(lines, start_idx)
    specs = []
    i = start_idx

    while i < lines.length && lines[i].match?(SPEC_ENTRY)
      line = lines[i]
      match = line.match(SPEC_ENTRY)
      name = match[1]
      version_string = match[2]

      # Parse version components to extract platform
      version_components = parse_version_components(version_string)

      dependencies = []
      i += 1

      while i < lines.length && lines[i].match?(DEPENDENCY_ENTRY)
        dep_match = lines[i].match(DEPENDENCY_ENTRY)
        dependencies << Dependency.new(
          name: dep_match[1],
          version_requirements: dep_match[2]
        )
        i += 1
      end

      specs << Spec.new(
        name: name,
        version: version_components ? version_components[:version] : version_string,
        platform: version_components ? version_components[:platform] : "ruby",
        raw: version_components ? version_components[:raw] : version_string,
        dependencies: dependencies
      )
    end

    [specs, i]
  end

  def parse_platforms(lines, start_idx)
    platforms = []
    i = start_idx

    while i < lines.length && lines[i].match?(PLATFORM_ENTRY) && !section_header?(lines[i])
      match = lines[i].match(PLATFORM_ENTRY)
      platforms << Platform.new(name: match[1])
      i += 1
    end

    [platforms, i]
  end

  def parse_dependencies(lines, start_idx)
    dependencies = []
    i = start_idx

    while i < lines.length && lines[i].match?(TOP_LEVEL_DEPENDENCY)
      match = lines[i].match(TOP_LEVEL_DEPENDENCY)
      dependencies << Dependency.new(
        name: match[1],
        version_requirements: match[2]
      )
      i += 1
    end

    [dependencies, i]
  end

  def parse_ruby_version(lines, start_idx)
    return [nil, start_idx] if start_idx >= lines.length

    line = lines[start_idx]
    return [nil, start_idx] unless line.match?(VERSION_LINE)

    version_string = line.match(VERSION_LINE)[1]
    parts = version_string.split # ["ruby", "2.7.2p137", "(truffleruby 25.0.0)"]

    version, patchlevel = parts[1].split("p")
    engine = parts[2] if parts.length > 2

    ruby_version = RubyVersion.new(
      version: version,
      engine: engine,
      patchlevel: patchlevel
    )

    [ruby_version, start_idx + 1]
  end

  def parse_bundled_with(lines, start_idx)
    return [nil, start_idx] if start_idx >= lines.length

    line = lines[start_idx]
    return [nil, start_idx] unless line.match?(BUNDLED_VERSION)

    version = line.match(BUNDLED_VERSION)[1]
    [version, start_idx + 1]
  end

  def skip_section(lines, start_idx)
    i = start_idx
    i += 1 while i < lines.length && !section_header?(lines[i])
    i
  end

  def section_header?(line)
    line.match?(GEM) || line.match?(GIT) || line.match?(PATH) ||
      line.match?(PLUGIN) || line.match?(PLATFORMS) ||
      line.match?(DEPENDENCIES) || line.match?(RUBY) ||
      line.match?(BUNDLED_WITH) || line.match?(CHECKSUMS)
  end

  def parse_version_components(version_string)
    return nil unless version_string

    if (match = version_string.match(PLATFORM_PATTERN))
      {
        raw: version_string,
        version: version_string.sub(PLATFORM_PATTERN, ""),
        platform: match[1]
      }
    else
      {
        raw: version_string,
        version: version_string,
        platform: "ruby"
      }
    end
  end
end

if __FILE__ == $0
  if ARGV.length != 1
    puts "Usage: ruby lockfile_parser.rb <path_to_Gemfile.lock>"
    exit 1
  end

  lockfile_content = File.read(ARGV[0])

  result = LockfileParser.new.parse(lockfile_content)

  puts "Sources: #{result.sources.map(&:remote).inspect}"
  puts "Platforms: #{result.platforms.map(&:name).inspect}"
  puts "Dependencies: #{result.dependencies.count}"
  puts "Specs: #{result.sources.sum { |s| s.specs.count }}"
  puts "Ruby Version: #{result.ruby_version&.version}"
  puts "Bundled With: #{result.bundled_with}"
end
