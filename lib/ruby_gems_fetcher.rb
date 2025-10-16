require "json"
require "gems"
require "uri"
require "time"
require "fileutils"
require "rubygems"

class RubyGemsFetcher
  CACHE_DIR = "cache"
  CACHE_EXPIRATION = 86400 # 24 hours in seconds
  RATE_LIMIT = 10 # https://guides.rubygems.org/rubygems-org-rate-limits/
  RATE_LIMIT_INTERVAL = 1.0 / RATE_LIMIT

  def initialize(remotes:)
    @credentials_by_remote = build_credentials_index
    @remotes = Array(remotes)
      .map { |remote| canonicalize_remote(remote) }
      .compact
      .uniq
    @clients = {}
    @last_request_time = Hash.new { |hash, key| hash[key] = Time.now - RATE_LIMIT_INTERVAL }
    @remotes.each { |remote| client_for(remote) }
  end

  def fetch_gem_versions(gem_name, remote:)
    canonical_remote = canonicalize_remote(remote)
    return nil unless canonical_remote

    cache_file = cache_path(canonical_remote, gem_name)
    if cache_valid?(cache_file)
      JSON.parse(File.read(cache_file))
    else
      client = client_for(canonical_remote)
      return nil unless client

      rate_limiter(canonical_remote)
      versions = client.versions(gem_name)
      FileUtils.mkdir_p(File.dirname(cache_file))
      File.write(cache_file, JSON.dump(versions))
      File.utime(Time.now, Time.now, cache_file)
      versions
    end
  rescue Gems::DependencyError, Gems::NotFound
    nil
  end

  private

  def cache_valid?(cache_file)
    return false unless File.exist?(cache_file)

    cache_age = Time.now - File.mtime(cache_file)
    cache_age < CACHE_EXPIRATION
  end

  def client_for(remote)
    canonical_remote = canonicalize_remote(remote)
    return nil unless canonical_remote

    @remotes << canonical_remote unless @remotes.include?(canonical_remote)
    @clients[canonical_remote] ||= build_client(canonical_remote)
  end

  def build_client(remote)
    return nil if remote.nil? || remote.empty?

    client_options = {
      host: remote
    }

    credentials = credentials_for(remote)
    if credentials
      client_options[:username] = credentials[:username] if credentials[:username]
      client_options[:password] = credentials[:password] if credentials[:password]
    end

    Gems::Client.new(client_options)
  rescue ArgumentError
    nil
  end

  def rate_limiter(remote)
    now = Time.now
    elapsed = now - @last_request_time[remote]
    sleep(RATE_LIMIT_INTERVAL - elapsed) if elapsed < RATE_LIMIT_INTERVAL
    @last_request_time[remote] = Time.now
  end

  def cache_path(remote, gem_name)
    host_key = remote.gsub(%r{[^a-zA-Z0-9]}, "_")
    File.join(CACHE_DIR, host_key, "#{gem_name}.json")
  end

  def credentials_for(remote)
    canonical_remote = canonicalize_remote(remote)
    return nil unless canonical_remote

    @credentials_by_remote[canonical_remote]
  end

  def build_credentials_index
    return {} unless Gem.respond_to?(:sources)

    Gem.sources.sources.each_with_object({}) do |source, memo|
      uri = source.uri
      next unless uri

      canonical = canonicalize_remote(uri)
      next unless canonical

      username = uri.user
      password = uri.password

      memo[canonical] = {
        username: username,
        password: password
      }.compact
    end
  end

  def canonicalize_remote(remote)
    return nil if remote.nil?

    remote_string = remote.to_s.strip
    return nil if remote_string.empty?

    uri = remote_string.is_a?(URI::Generic) ? remote_string.dup : URI.parse(remote_string)
    uri = uri.dup
    uri.user = nil if uri.respond_to?(:user=)
    uri.password = nil if uri.respond_to?(:password=)
    normalized = uri.to_s
    normalized = "#{normalized}/" unless normalized.end_with?("/")
    normalized
  rescue URI::InvalidURIError
    nil
  end
end
