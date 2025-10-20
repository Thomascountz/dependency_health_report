# frozen_string_literal: true

require "octokit"
require "base64"

class GitHubClient
  def initialize(logger = nil, token = ENV["GITHUB_API_TOKEN"])
    @client = Octokit::Client.new(access_token: token)
    @client.auto_paginate = true
    @logger = logger
    @content_cache = {}
    @commit_cache = {}
    @api_calls_made = 0
  end

  def fetch_gemfile_lock_commits(repo_url)
    owner, repo = extract_owner_repo(repo_url)
    return [] unless owner && repo

    check_rate_limit_and_sleep

    commits = @client.commits("#{owner}/#{repo}", path: "Gemfile.lock")
    @api_calls_made += 1

    commits.map do |commit|
      {
        sha: commit.sha,
        date: commit.commit.committer.date,
        message: commit.commit.message,
        owner: owner,
        repo: repo
      }
    end
  rescue Octokit::NotFound, Octokit::Forbidden => e
    @logger&.warn("Skipping repository: #{e.message}", {repo: repo_url})
    []
  end

  def fetch_gemfile_lock_content(owner, repo, sha)
    cache_key = "#{owner}/#{repo}@#{sha}"
    return @content_cache[cache_key] if @content_cache.key?(cache_key)

    check_rate_limit_and_sleep

    begin
      content = @client.contents("#{owner}/#{repo}", path: "Gemfile.lock", ref: sha)
      @api_calls_made += 1
      decoded_content = Base64.decode64(content.content)
      @content_cache[cache_key] = decoded_content
      decoded_content
    rescue Octokit::NotFound
      @logger&.warn("Gemfile.lock not found at #{owner}/#{repo}@#{sha}")
      @content_cache[cache_key] = nil
      nil
    end
  end

  def get_commit_parents(owner, repo, sha)
    cache_key = "#{owner}/#{repo}@#{sha}"
    return @commit_cache[cache_key] if @commit_cache.key?(cache_key)

    check_rate_limit_and_sleep

    begin
      commit = @client.commit("#{owner}/#{repo}", sha)
      @api_calls_made += 1
      parents = commit.parents.map(&:sha)
      @commit_cache[cache_key] = parents
      parents
    rescue Octokit::NotFound
      @logger&.warn("Commit not found: #{owner}/#{repo}@#{sha}")
      @commit_cache[cache_key] = []
      []
    end
  end

  private

  def extract_owner_repo(repo_url)
    # Extract "zendesk" and "ruby-core" from "https://github.com/zendesk/ruby-core"
    match = repo_url.match(%r{github\.com/([^/]+)/([^/]+)/?$})
    return nil unless match
    [match[1], match[2]]
  end

  def check_rate_limit_and_sleep
    rate_limit = @client.rate_limit
    remaining = rate_limit.remaining

    if remaining <= 100  # Conservative threshold
      reset_time = rate_limit.resets_at
      sleep_duration = reset_time - Time.now + 10  # Add 10 second buffer

      if sleep_duration > 0
        @logger&.warn("Rate limit low (#{remaining} remaining). Sleeping for #{sleep_duration.to_i} seconds...")
        sleep(sleep_duration)
      end
    end

    # Log API usage periodically
    if @api_calls_made > 0 && @api_calls_made % 100 == 0
      @logger&.info("GitHub API calls made: #{@api_calls_made}. Rate limit remaining: #{remaining}")
    end
  end
end
