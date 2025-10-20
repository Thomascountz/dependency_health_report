# frozen_string_literal: true

require "sequel"

DEFAULT_DB_PATH = "out/dependency_health.db"

class Database
  def initialize(db_path = DEFAULT_DB_PATH)
    @db = Sequel.sqlite(db_path)
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
      @db[:gem_versions].insert(
        gem_id: gem_id,
        version_number: version_number,
        release_date: release_date,
        prerelease: prerelease ? 1 : 0,
        first_seen_at: Time.now,
        last_seen_at: Time.now
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
    @db[:snapshots].insert_conflict(:replace).insert(data)
  end

  def insert_lockfile_entry(data)
    @db[:lockfile_entries].insert(data)
  end

  def repository_processed?(repo_url)
    @db[:processed_repositories].where(repository_url: repo_url, status: "completed").count > 0
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

  private

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

      foreign_key [:gem_id], :gems, key: :id
      unique [:gem_id, :version_number]
      index :gem_id
      index :version_number
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
