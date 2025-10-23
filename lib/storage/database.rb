# frozen_string_literal: true

require "sequel"

DEFAULT_DB_PATH = "out/dependency_health.db"

class Database
  def initialize(db_path = DEFAULT_DB_PATH)
    @db = Sequel.sqlite(db_path)
    configure_sqlite
    create_tables
  end

  def upsert_gem_source(source_type, remote_url)
    existing = @db[:gem_sources].where(type: source_type, remote_url: remote_url).first

    if existing
      existing[:id]
    else
      @db[:gem_sources].insert(
        type: source_type,
        remote_url: remote_url,
        created_at: Time.now
      )
    end
  end

  def upsert_gem(name, source_id)
    existing = @db[:gems].where(name: name, source_id: source_id).first

    if existing
      existing[:id]
    else
      @db[:gems].insert(
        name: name,
        source_id: source_id,
        created_at: Time.now
      )
    end
  end

  def upsert_gem_version(gem_id, version_number, release_date, prerelease)
    existing = @db[:gem_versions].where(gem_id: gem_id, version_number: version_number).first

    if existing
      # Update last_seen_at
      @db[:gem_versions].where(id: existing[:id]).update(last_seen_at: Time.now)
      existing[:id]
    else
      # Parse semver components
      require_relative "../semver_parser" unless defined?(SemverParser)
      parsed = SemverParser.parse(version_number)

      @db[:gem_versions].insert(
        gem_id: gem_id,
        version_number: version_number,
        release_date: release_date,
        prerelease: prerelease ? 1 : 0,
        first_seen_at: Time.now,
        last_seen_at: Time.now,
        # Semver components
        major: parsed[:major],
        minor: parsed[:minor],
        patch: parsed[:patch],
        prerelease_type: parsed[:prerelease_type],
        prerelease_number: parsed[:prerelease_number],
        build_metadata: parsed[:build_metadata]
      )
    end
  end

  # New method that accepts a GemVersion object directly
  def upsert_gem_version_object(gem_id, gem_version)
    existing = @db[:gem_versions].where(gem_id: gem_id, version_number: gem_version.version_string).first

    if existing
      # Update last_seen_at
      @db[:gem_versions].where(id: existing[:id]).update(last_seen_at: Time.now)
      existing[:id]
    else
      @db[:gem_versions].insert(
        gem_id: gem_id,
        version_number: gem_version.version_string,
        release_date: gem_version.created_at,
        prerelease: gem_version.prerelease? ? 1 : 0,
        first_seen_at: Time.now,
        last_seen_at: Time.now,
        # Semver components from GemVersion object
        major: gem_version.major,
        minor: gem_version.minor,
        patch: gem_version.patch,
        prerelease_type: gem_version.prerelease_type,
        prerelease_number: gem_version.prerelease_number,
        build_metadata: gem_version.build_metadata
      )
    end
  end

  def upsert_repository(remote_url)
    existing = @db[:repositories].where(remote_url: remote_url).first

    if existing
      # Update updated_at
      @db[:repositories].where(id: existing[:id]).update(updated_at: Time.now)
      existing[:id]
    else
      @db[:repositories].insert(
        remote_url: remote_url,
        created_at: Time.now,
        updated_at: Time.now
      )
    end
  end

  def insert_snapshot(data)
    existing = @db[:snapshots].where(
      repository_id: data[:repository_id],
      commit_sha: data[:commit_sha],
      as_of_date: data[:as_of_date]
    ).first

    return existing[:id] if existing

    @db[:snapshots].insert_conflict(:replace).insert(data)
  end

  def insert_lockfile_entry(data)
    # Use upsert to handle re-runs gracefully
    # First try to find existing entry
    existing = @db[:lockfile_entries].where(
      snapshot_id: data[:snapshot_id],
      gem_version_id: data[:gem_version_id]
    ).first

    if existing
      # Update the existing entry
      # @db[:lockfile_entries].where(id: existing[:id]).update(
      #   latest_gem_version_id: data[:latest_gem_version_id],
      #   version_distance: data[:version_distance],
      #   libyear_in_days: data[:libyear_in_days],
      #   is_direct: data[:is_direct]
      # )
      existing[:id]
    else
      # Insert new entry
      @db[:lockfile_entries].insert(data)
    end
  end

  def repository_processed?(repo_url)
    @db[:processed_repositories].where(repository_url: repo_url, status: "completed").count > 0
  end

  def commit_processed?(repo_url, commit_sha)
    @db[:snapshots].where(commit_sha: commit_sha).count > 0
  end

  def mark_repository_processed(repo_url, commits_analyzed, snapshots_created, status = "completed", error = nil)
    @db[:processed_repositories].insert_conflict(:replace).insert({
      repository_url: repo_url,
      last_processed_at: Time.now,
      commits_analyzed: commits_analyzed,
      snapshots_created: snapshots_created,
      status: status,
      error_message: error
    })
  end

  def [](table)
    @db[table]
  end

  def transaction(&block)
    @db.transaction(&block)
  end

  private

  def configure_sqlite
    # Enable Write-Ahead Logging for better concurrency
    # WAL mode allows multiple readers and one writer to operate concurrently
    @db.run("PRAGMA journal_mode=WAL")

    # Set busy timeout to 5 seconds (5000ms) to wait for locks instead of failing immediately
    @db.run("PRAGMA busy_timeout=5000")

    # Enable foreign key constraints (they are disabled by default in SQLite)
    @db.run("PRAGMA foreign_keys=ON")
  end

  def create_tables
    @db.create_table?(:gem_sources) do
      primary_key :id
      String :type, null: false
      String :remote_url, null: false
      DateTime :created_at, default: Sequel::CURRENT_TIMESTAMP

      unique [:type, :remote_url]
    end

    @db.create_table?(:gems) do
      primary_key :id
      String :name, null: false
      Integer :source_id, null: false
      DateTime :created_at, default: Sequel::CURRENT_TIMESTAMP

      foreign_key [:source_id], :gem_sources, key: :id
      unique [:name, :source_id]
      index :name
    end

    @db.create_table?(:gem_versions) do
      primary_key :id
      Integer :gem_id, null: false
      String :version_number, null: false
      Date :release_date
      Integer :prerelease, null: false, default: 0
      DateTime :first_seen_at, null: false
      DateTime :last_seen_at, null: false

      # Semver components
      Integer :major
      Integer :minor
      Integer :patch
      String :prerelease_type # 'alpha', 'beta', 'rc', 'pre', NULL
      Integer :prerelease_number
      String :build_metadata

      foreign_key [:gem_id], :gems, key: :id
      unique [:gem_id, :version_number]
      index :gem_id
      index :version_number
      index [:gem_id, :major, :minor, :patch, :prerelease_type], name: :gem_versions_semver_idx
    end

    @db.create_table?(:repositories) do
      primary_key :id
      String :remote_url, null: false, unique: true
      DateTime :created_at, default: Sequel::CURRENT_TIMESTAMP
      DateTime :updated_at, default: Sequel::CURRENT_TIMESTAMP

      index :remote_url
    end

    @db.create_table?(:snapshots) do
      primary_key :id
      Integer :repository_id, null: false
      String :commit_sha, null: false
      Date :commit_date, null: false
      DateTime :analyzed_at, null: false
      Date :as_of_date
      Integer :total_gems, null: false
      Integer :outdated_gems, null: false
      Float :avg_libyear
      Float :total_libyear
      Float :avg_version_distance

      foreign_key [:repository_id], :repositories, key: :id
      unique [:repository_id, :commit_sha, :as_of_date]
      index :repository_id
      index :commit_date
      index :commit_sha
    end

    @db.create_table?(:lockfile_entries) do
      primary_key :id
      Integer :snapshot_id, null: false
      Integer :gem_version_id, null: false
      Integer :latest_gem_version_id
      Integer :version_distance
      Integer :libyear_in_days
      Integer :is_direct, null: false, default: 0

      foreign_key [:snapshot_id], :snapshots, key: :id
      foreign_key [:gem_version_id], :gem_versions, key: :id
      foreign_key [:latest_gem_version_id], :gem_versions, key: :id
      unique [:snapshot_id, :gem_version_id]
      index :snapshot_id
      index :gem_version_id
    end

    @db.create_table?(:processed_repositories) do
      primary_key :id
      String :repository_url, null: false, unique: true
      DateTime :last_processed_at, default: Sequel::CURRENT_TIMESTAMP
      Integer :commits_analyzed
      Integer :snapshots_created
      String :status
      String :error_message

      index :status
    end
  end
end
