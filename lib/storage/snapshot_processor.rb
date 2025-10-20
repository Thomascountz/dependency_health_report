# frozen_string_literal: true

require_relative "lockfile_extractor"
require_relative "dependency_reporter"
require_relative "../../dependency_health_report"

class SnapshotProcessor
  def initialize(database, logger)
    @db = database
    @logger = logger
  end

  def process(repo_path, since: nil, worker_id: nil)
    # Skip if already processed
    extractor = LockfileExtractor.new(repo_path: repo_path, logger: @logger)
    remote_url = extractor.remote_url

    if @db.repository_processed?(remote_url)
      @logger.info("Skipping (already processed)", {repo: remote_url, worker_id: worker_id})
      return
    else
      @logger.info("Processing repository", {repo: remote_url, worker_id: worker_id})
    end

    begin
      commits = extractor.commits(since: since)

      if commits.empty?
        @db.mark_repository_processed(remote_url, 0, 0, "skipped", "No commits found")
        return
      else
        @logger.info("Found #{commits.size} commits", {repo: remote_url, worker_id: worker_id})
      end

      snapshots_created = 0

      commits.each do |commit|
        lockfile_contents = extractor.lockfile_at_commit(commit[:sha])

        if lockfile_contents.nil?
          @logger.warn("No Gemfile.lock at commit #{commit[:sha]}", {repo: remote_url, worker_id: worker_id})
          next
        else
          result = process_commit(remote_url, commit, lockfile_contents, worker_id)
          if result
            snapshots_created += 1
          else
            # Skip this commit (likely duplicate or error)
            next
          end
        end
      end

      @db.mark_repository_processed(remote_url, commits.size, snapshots_created)
      @logger.info("Completed (#{commits.size} commits, #{snapshots_created} snapshots)", {repo: remote_url, worker_id: worker_id})
    rescue => e
      @db.mark_repository_processed(remote_url, 0, 0, "failed", e.message)
      raise e
    end
  end

  private

  def process_commit(remote_url, commit, lockfile_contents, worker_id)
    # Create components for analysis
    lockfile_parser = LockfileParser.new(logger: StructuredLogger.new(nil))
    gem_info_fetcher = GemInfoFetcher.new(logger: StructuredLogger.new(nil))
    dependency_analyzer = DependencyAnalyzer.new(logger: StructuredLogger.new(nil))
    reporter = DependencyReporter.new

    # Run analysis
    health_report = DependencyHealthReport.new(
      lockfile_parser: lockfile_parser,
      gem_info_fetcher: gem_info_fetcher,
      dependency_analyzer: dependency_analyzer,
      reporter: reporter,
      logger: StructuredLogger.new(nil)
    )

    results = health_report.run(lockfile_contents, as_of: commit[:date])
    lockfile = lockfile_parser.parse(lockfile_contents)

    # Store results in database
    store_snapshot(remote_url, commit, lockfile, results)

    @logger.snapshot("Snapshot: #{commit[:sha][0..7]} (#{results.size} gems analyzed)", {repo: remote_url, worker_id: worker_id})

    true
  rescue => e
    @logger.error("Error processing commit #{commit[:sha]}: #{e.message}", {repo: remote_url, worker_id: worker_id})
    @logger.error("Backtrace: #{e.backtrace.first(3).join("\n")}", {repo: remote_url, worker_id: worker_id})
    false
  end

  def store_snapshot(remote_url, commit, lockfile, results)
    # Wrap all database operations in a transaction for better performance
    # and to reduce lock contention in multi-threaded scenarios
    @db.transaction do
      # Upsert repository
      repo_id = @db.upsert_repository(remote_url)

      # Store gem metadata
      gem_version_ids = {}

      lockfile.sources.each do |source|
        if source.type == :gem && !source.remote.nil?
          source_id = @db.upsert_gem_source(source.type.to_s, source.remote)
        else
          next
        end

        source.specs.each do |spec|
          gem_id = @db.upsert_gem(spec.name, source_id)

          # Find the result for this gem to get release date info
          result = results.find { |r| r.name == spec.name }

          if result
            current_release_date = result.current_version_release_date
            latest_release_date = result.latest_version_release_date
          else
            current_release_date = nil
            latest_release_date = nil
          end

          # Store current version
          current_version_id = @db.upsert_gem_version(
            gem_id,
            spec.version.to_s,
            current_release_date,
            false
          )

          gem_version_ids[spec.name] = {current: current_version_id}

          # Store latest version if available
          if result&.latest_version
            latest_version_id = @db.upsert_gem_version(
              gem_id,
              result.latest_version.to_s,
              latest_release_date,
              false
            )
            gem_version_ids[spec.name][:latest] = latest_version_id
          else
            gem_version_ids[spec.name][:latest] = nil
          end
        end
      end

      # Calculate summary metrics
      total_gems = lockfile.sources.flat_map(&:specs).size
      outdated_gems = results.count { |r| r.version_distance && r.version_distance > 0 }

      if results.any? && results.map(&:libyear_in_days).compact.any?
        total_libyear = results.map { |r| r.libyear_in_days || 0 }.sum
        avg_libyear = total_libyear.to_f / results.size
      else
        total_libyear = nil
        avg_libyear = nil
      end

      avg_version_distance = if results.any? && results.map(&:version_distance).compact.any?
        results.map { |r| r.version_distance || 0 }.sum.to_f / results.size
      end

      # Insert snapshot
      snapshot_id = @db.insert_snapshot({
        repository_id: repo_id,
        commit_sha: commit[:sha],
        commit_date: commit[:date],
        analyzed_at: Time.now,
        as_of_date: commit[:date],
        total_gems: total_gems,
        outdated_gems: outdated_gems,
        avg_libyear: avg_libyear,
        total_libyear: total_libyear,
        avg_version_distance: avg_version_distance
      })

      # Insert lockfile entries
      results.each do |result|
        gem_ids = gem_version_ids[result.name]
        if gem_ids
          @db.insert_lockfile_entry({
            snapshot_id: snapshot_id,
            gem_version_id: gem_ids[:current],
            latest_gem_version_id: gem_ids[:latest],
            version_distance: result.version_distance,
            libyear_in_days: result.libyear_in_days,
            is_direct: result.is_direct ? 1 : 0
          })
        else
          # Shouldn't happen, but skip if we don't have the gem version ID
          next
        end
      end
    end # transaction
  end
end
