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
    @gem_source_clients = {}
    @last_request_time = Hash.new { |hash, key| hash[key] = Time.now - RATE_LIMIT_INTERVAL }
  end

  def fetch_gem_versions(gem_name, remote_host:, as_of: nil)
    client = client_for(remote_host)
    return [] unless client

    raw_versions = fetch_raw_versions(client, remote_host, gem_name)
    build_versions(gem_name, raw_versions, as_of)
  end

  private

  def fetch_raw_versions(client, remote_host, gem_name)
    with_cache(remote_host, gem_name) do
      wait_for_rate_limit(remote_host)
      client.versions(gem_name)
    rescue Gems::GemError, Gems::NotFound
      []
    end
  end

  def build_versions(gem_name, raw_versions, as_of)
    Array(raw_versions)
      .map do |attributes|
        GemVersion.new(
          name: gem_name,
          number: Gem::Version.new(attributes["number"]),
          created_at: Date.parse(attributes["created_at"]),
          prerelease?: attributes["prerelease"]
        )
      end
      .reject { |version| version.prerelease? || (as_of && version.created_at > as_of) }
      .sort_by(&:number)
      .reverse
  end

  def client_for(remote_host)
    @gem_source_clients[remote_host] ||= begin
      source = source_for(remote_host)
      return nil unless source

      uri = source.uri
      Gems::Client.new(
        host: (uri.origin + uri.request_uri),
        username: uri.user,
        password: uri.password
      )
    end
  end

  def source_for(remote_host)
    Gem.sources.each_source.find { |gem_source| gem_source.uri.host == remote_host }
  end

  def wait_for_rate_limit(remote_host)
    now = Time.now
    elapsed = now - @last_request_time[remote_host]
    sleep(RATE_LIMIT_INTERVAL - elapsed) if elapsed < RATE_LIMIT_INTERVAL
    @last_request_time[remote_host] = Time.now
  end
end
