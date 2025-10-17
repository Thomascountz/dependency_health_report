# frozen_string_literal: true

require "json"
require "time"
require "fileutils"

module GemInfoCacher
  CACHE_DIR = ".cache"
  CACHE_EXPIRATION = 86_400 # 24 hours in seconds

  def with_cache(remote_host, gem_name, &block)
    if ENV["SKIP_CACHE"] == "1"
      return block.call
    end

    cache_file = cache_path(remote_host, gem_name)
    if cache_valid?(cache_file)
      JSON.parse(File.read(cache_file))
    else
      block.call.tap do |data|
        return [] unless data

        FileUtils.mkdir_p(File.dirname(cache_file))
        File.write(cache_file, JSON.dump(data))
        File.utime(Time.now, Time.now, cache_file)
      end
    end
  end

  private

  def cache_valid?(cache_file)
    return false unless File.exist?(cache_file)

    cache_age = Time.now - File.mtime(cache_file)
    cache_age < CACHE_EXPIRATION
  end

  def cache_path(remote_host, gem_name)
    host_key = remote_host.gsub(/[^a-zA-Z0-9]/, "_")
    File.join(CACHE_DIR, host_key, "#{gem_name}.json")
  end
end
