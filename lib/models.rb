Lockfile = Data.define(:sources, :platforms, :dependencies, :ruby_version, :bundled_with)
Source = Data.define(:type, :remote, :revision, :specs, :options)
Spec = Data.define(:name, :version, :platform, :raw, :dependencies)
Dependency = Data.define(:name, :version_requirements)
Platform = Data.define(:name)
RubyVersion = Data.define(:version, :engine, :patchlevel)

GemVersion = Data.define(:name, :number, :created_at, :prerelease?)
Result = Data.define(
  :name,
  :current_version,
  :current_version_release_date,
  :latest_version,
  :latest_version_release_date,
  :version_distance,
  :is_direct,
  :libyear_in_days
)
