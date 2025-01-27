require "json"
require "faraday"
require "time"

class RubyGemsFetcher
  CACHE_DIR = "cache"
  RUBYGEMS_API_URL = "https://rubygems.org/api/v1/versions"
  CACHE_EXPIRATION = 86400 # 24 hours in seconds
  RATE_LIMIT = 10 # https://guides.rubygems.org/rubygems-org-rate-limits/
  RATE_LIMIT_INTERVAL = 1.0 / RATE_LIMIT

  def initialize
    @last_request_time = Time.now - RATE_LIMIT_INTERVAL
  end

  def fetch_gem_versions(gem_name)
    cache_file = "#{CACHE_DIR}/#{gem_name}.json"
    if cache_valid?(cache_file)
      JSON.parse(File.read(cache_file))
    else
      rate_limiter
      response = Faraday.get("#{RUBYGEMS_API_URL}/#{gem_name}.json").body
      File.write(cache_file, response)
      File.utime(Time.now, Time.now, cache_file) # Update the file's access and modification times
      JSON.parse(response)
    end
  end

  private

  def cache_valid?(cache_file)
    return false unless File.exist?(cache_file)
    cache_age = Time.now - File.mtime(cache_file)
    cache_age < CACHE_EXPIRATION
  end

  def rate_limiter
    now = Time.now
    elapsed = now - @last_request_time
    sleep(RATE_LIMIT_INTERVAL - elapsed) if elapsed < RATE_LIMIT_INTERVAL
    @last_request_time = Time.now
  end
end
