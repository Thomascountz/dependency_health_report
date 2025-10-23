# frozen_string_literal: true

require_relative "../gem_info_fetcher"
require_relative "../structured_logger"
require_relative "../models"
require "time"

class VersionBackfiller
  def initialize(database, logger: StructuredLogger.new($stderr))
    @db = database
    @logger = logger
    @gem_info_fetcher = GemInfoFetcher.new(logger: StructuredLogger.new(nil))
  end

  def backfill_versions(dry_run: false)
    @logger.info("Starting version backfill", {dry_run: dry_run})

    # Get the date range from all snapshots
    date_range = get_analysis_date_range
    if date_range.nil?
      @logger.info("No snapshots found in database, nothing to backfill")
      return
    end

    min_date, max_date = date_range
    @logger.info("Analysis date range: #{min_date} to #{max_date} (#{(max_date - min_date).to_i} days)")

    # Get all unique gems that have been analyzed
    gems_to_process = get_analyzed_gems
    @logger.info("Found #{gems_to_process.count} unique gems to process")

    # Track statistics
    stats = {
      gems_processed: 0,
      versions_added: 0,
      versions_skipped: 0,
      errors: 0
    }

    # Process each gem
    gems_to_process.each_with_index do |gem_info, index|
      if index % 10 == 0
        @logger.progress("Processing gem #{index + 1}/#{gems_to_process.count}")
      end

      begin
        versions_added = process_gem(gem_info, min_date, max_date, dry_run: dry_run)
        stats[:gems_processed] += 1
        stats[:versions_added] += versions_added
      rescue => e
        @logger.error("Error processing gem #{gem_info[:name]}: #{e.message}")
        stats[:errors] += 1
      end
    end

    # Final summary
    @logger.info("Backfill complete", stats)
    stats
  end

  private

  # Rubocop things .select().first can be .find, but this is Sequel syntax
  # rubocop:disable Performance/Detect
  def get_analysis_date_range
    result = @db[:snapshots]
      .select {
      [
        Sequel.function(:min, :commit_date).as(:min_date),
        Sequel.function(:max, :commit_date).as(:max_date)
      ]
    }.first

    return nil if result.nil? || result[:min_date].nil?

    [Date.parse(result[:min_date].to_s), Date.parse(result[:max_date].to_s)]
  end
  # rubocop:enable Performance/Detect

  def get_analyzed_gems
    # Get all unique gems with their source information
    @db[:gems]
      .join(:gem_sources, id: :source_id)
      .select(
        Sequel[:gems][:id].as(:id),
        Sequel[:gems][:name].as(:name),
        Sequel[:gem_sources][:remote_url].as(:remote_url)
      )
      .distinct
      .all
  end

  def process_gem(gem_info, min_date, max_date, dry_run: false)
    gem_id = gem_info[:id]
    gem_name = gem_info[:name]
    remote_url = gem_info[:remote_url]

    # Extract host from remote URL
    begin
      uri = URI.parse(remote_url)
      remote_host = uri.host
    rescue URI::InvalidURIError
      @logger.warn("Invalid remote URL for gem #{gem_name}: #{remote_url}")
      return 0
    end

    # Fetch all versions for this gem
    all_versions = @gem_info_fetcher.gem_versions_for(gem_name, remote_host)

    if all_versions.empty?
      return 0
    end

    # Filter versions released before or within our analysis date range
    # We want all versions that existed as of the max_date (latest snapshot)
    versions_in_range = all_versions.select do |version|
      version.created_at <= max_date
    end

    if versions_in_range.empty? && !all_versions.empty?
      @logger.info("No versions in date range for #{gem_name}: #{min_date} to #{max_date}. Found #{all_versions.count} total versions (earliest: #{all_versions.last&.created_at}, latest: #{all_versions.first&.created_at})")
    end

    versions_added = 0

    @db.transaction do
      versions_in_range.each do |version|
        # Check if this version already exists
        existing = @db[:gem_versions].where(
          gem_id: gem_id,
          version_number: version.number.to_s
        ).first

        if existing
          # Version already exists, update release_date if missing
          if existing[:release_date].nil? && version.created_at
            if !dry_run
              @db[:gem_versions]
                .where(id: existing[:id])
                .update(release_date: version.created_at)
            end
          end
        else
          # New version - add it
          if dry_run
            # Just count it
          else
            @db[:gem_versions].insert(
              gem_id: gem_id,
              version_number: version.version_string,
              release_date: version.created_at,
              prerelease: version.prerelease? ? 1 : 0,
              first_seen_at: Time.now,
              last_seen_at: Time.now,
              # Semver components from GemVersion object
              major: version.major,
              minor: version.minor,
              patch: version.patch,
              prerelease_type: version.prerelease_type,
              prerelease_number: version.prerelease_number,
              build_metadata: version.build_metadata
            )
          end
          versions_added += 1
        end
      end
    end

    versions_added
  end
end
