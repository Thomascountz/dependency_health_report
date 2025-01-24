require 'json'
require 'net/http'

class GemFetcher
  CACHE_DIR = "cache"
  RUBYGEMS_API_URL = "https://rubygems.org/api/v1/versions"

  def fetch_gem_versions(gem_name)
    cache_file = "#{CACHE_DIR}/#{gem_name}.json"
    if File.exist?(cache_file)
      JSON.parse(File.read(cache_file))
    else
      response = Net::HTTP.get(URI("#{RUBYGEMS_API_URL}/#{gem_name}.json"))
      File.write(cache_file, response)
      JSON.parse(response)
    end
  end
end
