# frozen_string_literal: true

require_relative "test_helper"

class LockfileParserTest < Minitest::Test
  def test_parses_gem_source_with_remote
    parser = LockfileParser.new(logger: StructuredLogger.new(nil))
    lockfile_content = <<~LOCKFILE
      GEM
        remote: https://rubygems.org/
        specs:

      PLATFORMS
        ruby

      DEPENDENCIES

      BUNDLED WITH
         2.6.2
    LOCKFILE

    result = parser.parse(lockfile_content)

    assert_equal 1, result.sources.length
    assert_equal :gem, result.sources.first.type
    assert_equal "https://rubygems.org/", result.sources.first.remote
  end

  def test_parses_specs_with_versions
    parser = LockfileParser.new(logger: StructuredLogger.new(nil))
    lockfile_content = <<~LOCKFILE
      GEM
        remote: https://rubygems.org/
        specs:
          rails (7.0.0)
          rake (13.0.0)

      PLATFORMS
        ruby

      DEPENDENCIES
        rails
        rake

      BUNDLED WITH
         2.6.2
    LOCKFILE

    result = parser.parse(lockfile_content)

    specs = result.sources.first.specs
    assert_equal 2, specs.length
    assert_equal "rails", specs[0].name
    assert_equal "7.0.0", specs[0].version
    assert_equal "rake", specs[1].name
    assert_equal "13.0.0", specs[1].version
  end

  def test_parses_specs_with_dependencies
    parser = LockfileParser.new(logger: StructuredLogger.new(nil))
    lockfile_content = <<~LOCKFILE
      GEM
        remote: https://rubygems.org/
        specs:
          rails (7.0.0)
            activesupport (= 7.0.0)
            railties (= 7.0.0)

      PLATFORMS
        ruby

      DEPENDENCIES
        rails

      BUNDLED WITH
         2.6.2
    LOCKFILE

    result = parser.parse(lockfile_content)

    rails_spec = result.sources.first.specs.first
    assert_equal "rails", rails_spec.name
    assert_equal 2, rails_spec.dependencies.length
    assert_equal "activesupport", rails_spec.dependencies[0].name
    assert_equal "= 7.0.0", rails_spec.dependencies[0].version_requirements
    assert_equal "railties", rails_spec.dependencies[1].name
    assert_equal "= 7.0.0", rails_spec.dependencies[1].version_requirements
  end

  def test_parses_platforms
    parser = LockfileParser.new(logger: StructuredLogger.new(nil))
    lockfile_content = <<~LOCKFILE
      GEM
        remote: https://rubygems.org/
        specs:

      PLATFORMS
        ruby
        x86_64-linux

      DEPENDENCIES

      BUNDLED WITH
         2.6.2
    LOCKFILE

    result = parser.parse(lockfile_content)

    assert_equal 2, result.platforms.length
    assert_equal "ruby", result.platforms[0].name
    assert_equal "x86_64-linux", result.platforms[1].name
  end

  def test_parses_dependencies
    parser = LockfileParser.new(logger: StructuredLogger.new(nil))
    lockfile_content = <<~LOCKFILE
      GEM
        remote: https://rubygems.org/
        specs:
          rails (7.0.0)

      PLATFORMS
        ruby

      DEPENDENCIES
        rails (~> 7.0)
        rake (>= 13.0)

      BUNDLED WITH
         2.6.2
    LOCKFILE

    result = parser.parse(lockfile_content)

    assert_equal 2, result.dependencies.length
    assert_equal "rails", result.dependencies[0].name
    assert_equal "~> 7.0", result.dependencies[0].version_requirements
    assert_equal "rake", result.dependencies[1].name
    assert_equal ">= 13.0", result.dependencies[1].version_requirements
  end

  def test_parses_ruby_version
    parser = LockfileParser.new(logger: StructuredLogger.new(nil))
    lockfile_content = <<~LOCKFILE
      GEM
        remote: https://rubygems.org/
        specs:

      PLATFORMS
        ruby

      DEPENDENCIES

      RUBY VERSION
         ruby 3.4.6p0

      BUNDLED WITH
         2.6.2
    LOCKFILE

    result = parser.parse(lockfile_content)

    refute_nil result.ruby_version
    assert_equal "3.4.6", result.ruby_version.version
    assert_equal "0", result.ruby_version.patchlevel
  end

  def test_parses_bundled_with_version
    parser = LockfileParser.new(logger: StructuredLogger.new(nil))
    lockfile_content = <<~LOCKFILE
      GEM
        remote: https://rubygems.org/
        specs:

      PLATFORMS
        ruby

      DEPENDENCIES

      BUNDLED WITH
         2.6.2
    LOCKFILE

    result = parser.parse(lockfile_content)

    assert_equal "2.6.2", result.bundled_with
  end

  def test_parses_git_source
    parser = LockfileParser.new(logger: StructuredLogger.new(nil))
    lockfile_content = <<~LOCKFILE
      GIT
        remote: https://github.com/rails/rails.git
        revision: abc123def456
        specs:
          rails (7.1.0.alpha)

      PLATFORMS
        ruby

      DEPENDENCIES
        rails!

      BUNDLED WITH
         2.6.2
    LOCKFILE

    result = parser.parse(lockfile_content)

    git_source = result.sources.first
    assert_equal :git, git_source.type
    assert_equal "https://github.com/rails/rails.git", git_source.remote
    assert_equal "abc123def456", git_source.revision
    assert_equal 1, git_source.specs.length
    assert_equal "rails", git_source.specs.first.name
  end

  def test_parses_multiple_gem_sources
    parser = LockfileParser.new(logger: StructuredLogger.new(nil))
    lockfile_content = <<~LOCKFILE
      GEM
        remote: https://rubygems.org/
        specs:
          rails (7.0.0)

      GEM
        remote: https://gems.example.com/
        specs:
          private-gem (1.0.0)

      PLATFORMS
        ruby

      DEPENDENCIES
        rails
        private-gem

      BUNDLED WITH
         2.6.2
    LOCKFILE

    result = parser.parse(lockfile_content)

    assert_equal 2, result.sources.length
    assert_equal "https://rubygems.org/", result.sources[0].remote
    assert_equal "https://gems.example.com/", result.sources[1].remote
  end

  def test_skips_checksums_section
    parser = LockfileParser.new(logger: StructuredLogger.new(nil))
    lockfile_content = <<~LOCKFILE
      GEM
        remote: https://rubygems.org/
        specs:
          rails (7.0.0)

      CHECKSUMS
        rails (7.0.0) sha256=abc123
        rake (13.0.0) sha256=def456

      PLATFORMS
        ruby

      DEPENDENCIES
        rails

      BUNDLED WITH
         2.6.2
    LOCKFILE

    result = parser.parse(lockfile_content)

    # Should parse successfully without errors
    assert_equal 1, result.sources.length
    assert_equal 1, result.sources.first.specs.length
  end

  def test_handles_empty_lockfile
    parser = LockfileParser.new(logger: StructuredLogger.new(nil))
    lockfile_content = ""

    result = parser.parse(lockfile_content)

    assert_equal 0, result.sources.length
    assert_equal 0, result.platforms.length
    assert_equal 0, result.dependencies.length
    assert_nil result.ruby_version
    assert_nil result.bundled_with
  end
end
