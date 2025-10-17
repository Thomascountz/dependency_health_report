# frozen_string_literal: true

require_relative "gem_info_cacher"

require "gems"
require "uri"
require "time"
require "date"
require "rubygems"

class GemInfoFetcher
  include GemInfoCacher

  RATE_LIMIT = 10 # https://guides.rubygems.org/rubygems-org-rate-limits/
  RATE_LIMIT_INTERVAL = 1.0 / RATE_LIMIT

  def initialize
    @gem_source_clients = Gem.sources.each_source.each_with_object({}) do |gem_source, clients|
      uri = gem_source.uri

      clients[uri.host] = Gems::Client.new(
        host: (uri.origin + uri.request_uri),
        username: uri.user,
        password: uri.password
      )
    end
    @last_request_time = Hash.new { |hash, key| hash[key] = Time.now - RATE_LIMIT_INTERVAL }
  end

  def fetch_gem_versions(gem_name, remote_host:, as_of: nil)
    client = @gem_source_clients[remote_host]
    return [] unless client

    with_cache(remote_host, gem_name) do
      rate_limiter(remote_host)
      client.versions(gem_name)
    rescue Gems::GemError, Gems::NotFound
      []
    end.map do |v|
      GemVersion.new(
        name: gem_name,
        number: Gem::Version.new(v["number"]),
        created_at: Date.parse(v["created_at"]),
        prerelease?: v["prerelease"]
      )
    end.reject { |v| v.prerelease? || (as_of && v.created_at > as_of) }
      .sort_by(&:number)
      .reverse
  end

  private

  def rate_limiter(remote_host)
    now = Time.now
    elapsed = now - @last_request_time[remote_host]
    sleep(RATE_LIMIT_INTERVAL - elapsed) if elapsed < RATE_LIMIT_INTERVAL
    @last_request_time[remote_host] = Time.now
  end
end
