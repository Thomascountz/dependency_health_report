# frozen_string_literal: true

require "date"
require_relative "github_client"

class LockfileExtractor
  class GitError < StandardError; end

  def initialize(repo_path:, logger: nil)
    @repo_path = repo_path
    @logger = logger
    @is_github = github_url?(@repo_path)

    if @is_github
      @github_client = GitHubClient.new(@logger)
    else
      validate_git_repo!
    end
  end

  def commits(since: nil)
    if @is_github
      fetch_github_commits(since)
    else
      fetch_local_commits(since)
    end
  end

  def lockfile_at_commit(sha)
    if @is_github
      owner, repo = extract_owner_repo(@repo_path)
      @github_client.fetch_gemfile_lock_content(owner, repo, sha)
    else
      fetch_local_lockfile(sha)
    end
  end

  def remote_url
    if @is_github
      @repo_path
    else
      fetch_local_remote_url
    end
  end

  private

  def github_url?(path)
    path.match?(%r{github\.com/})
  end

  def extract_owner_repo(repo_url)
    match = repo_url.match(%r{github\.com/([^/]+)/([^/]+)/?$})
    return nil unless match
    [match[1], match[2].sub(/\.git$/, "")]
  end

  def fetch_github_commits(since)
    commits = @github_client.fetch_gemfile_lock_commits(@repo_path)

    if since
      since_date = Date.parse(since)
      commits.select { |commit| Date.parse(commit[:date].to_s) >= since_date }
    else
      commits
    end.map do |commit|
      {sha: commit[:sha], date: Date.parse(commit[:date].to_s)}
    end
  end

  def fetch_local_commits(since)
    cmd = "git -C \"#{@repo_path}\" log --reverse --format=\"%H|%ci\""
    cmd += if since
      " --since=\"#{since}\""
    else
      ""
    end

    output = `#{cmd}`
    exit_code = $?.exitstatus

    if exit_code != 0
      raise GitError, "Failed to get git log from #{@repo_path}"
    else
      parse_commits(output)
    end
  end

  def fetch_local_lockfile(sha)
    cmd = "git -C \"#{@repo_path}\" show #{sha}:Gemfile.lock 2>/dev/null"
    output = `#{cmd}`
    exit_code = $?.exitstatus

    if exit_code != 0
      nil
    else
      output
    end
  end

  def fetch_local_remote_url
    cmd = "git -C \"#{@repo_path}\" config --get remote.origin.url 2>/dev/null"
    output = `#{cmd}`.strip
    exit_code = $?.exitstatus

    if exit_code != 0
      # Fallback to repo path if no remote
      @repo_path
    else
      output
    end
  end

  def validate_git_repo!
    cmd = "git -C \"#{@repo_path}\" rev-parse --git-dir 2>/dev/null"
    `#{cmd}`
    exit_code = $?.exitstatus

    if exit_code != 0
      raise GitError, "#{@repo_path} is not a valid git repository"
    end
  end

  def parse_commits(output)
    commits = []

    output.each_line do |line|
      parts = line.strip.split("|")
      if parts.length >= 2
        sha = parts[0]
        date_str = parts[1]
        commit_date = Date.parse(date_str)

        commits << {sha: sha, date: commit_date}
      else
        # Skip malformed lines
        next
      end
    end

    commits
  end
end
