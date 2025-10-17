# frozen_string_literal: true

require_relative "gem_info_cacher"

require "gems"
require "uri"
require "time"
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

  def fetch_gem_versions(gem_name, remote_host:)
    client = @gem_source_clients[remote_host]
    return nil unless client

    if ENV["SKIP_CACHE"] == "1"
      rate_limiter(remote_host)
      client.versions(gem_name)
    else
      with_cache(remote_host, gem_name) do
        rate_limiter(remote_host)
        client.versions(gem_name)
      end
    end
  rescue Gems::GemError, Gems::NotFound
    nil
  end

  private

  def rate_limiter(remote_host)
    now = Time.now
    elapsed = now - @last_request_time[remote_host]
    sleep(RATE_LIMIT_INTERVAL - elapsed) if elapsed < RATE_LIMIT_INTERVAL
    @last_request_time[remote_host] = Time.now
  end
end
