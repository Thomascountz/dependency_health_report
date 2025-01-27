Dir[File.join(__dir__, "lib", "**", "*.rb")].each { |file| require file }

require "bundler"

class DependencyHealthReport
  def initialize(
    lockfile_data,
    analyzer:,
    reporters:
  )
    @lockfile_data = lockfile_data
    @direct_dependencies = lockfile_data.dependencies.keys
    @analyzer = analyzer
    @reporters = reporters
  end

  def run
    dependency_freshness, cumulative_libyear_in_days = @analyzer.calculate_dependency_freshness(@lockfile_data, @direct_dependencies)
    risk_profile = @analyzer.categorize_risks(dependency_freshness)
    cumulative_risk_profile = @analyzer.calculate_cumulative_risk_profile(risk_profile, dependency_freshness.size)
    rating = @analyzer.determine_rating(cumulative_risk_profile)

    @reporters.each do |reporter|
      reporter.generate(dependency_freshness, cumulative_risk_profile, rating, cumulative_libyear_in_days)
    end
  end
end

lockfile = Bundler::LockfileParser.new(DATA.read)
dependency_analyzer = DependencyAnalyzer.new(RubyGemsFetcher.new)

DependencyHealthReport.new(
  lockfile,
  analyzer: dependency_analyzer,
  reporters: [ConsoleReporter.new]
).run

# Rail's Gemfile.lock from `main` on 2025-01-24
__END__
GIT
  remote: https://github.com/nahi/httpclient.git
  revision: d57cc6d5ffee1b566b5c189fe6dc8cc89570b812
  branch: master
  specs:
    httpclient (2.8.3)
      mutex_m
      webrick

GIT
  remote: https://github.com/rails/sdoc.git
  revision: cd75e36ce2d1acb66734c1390ffe33aa05479380
  branch: main
  specs:
    sdoc (3.0.0.alpha)
      nokogiri
      rdoc (>= 5.0)
      rouge

PATH
  remote: .
  specs:
    actioncable (8.1.0.alpha)
      actionpack (= 8.1.0.alpha)
      activesupport (= 8.1.0.alpha)
      nio4r (~> 2.0)
      websocket-driver (>= 0.6.1)
      zeitwerk (~> 2.6)
    actionmailbox (8.1.0.alpha)
      actionpack (= 8.1.0.alpha)
      activejob (= 8.1.0.alpha)
      activerecord (= 8.1.0.alpha)
      activestorage (= 8.1.0.alpha)
      activesupport (= 8.1.0.alpha)
      mail (>= 2.8.0)
    actionmailer (8.1.0.alpha)
      actionpack (= 8.1.0.alpha)
      actionview (= 8.1.0.alpha)
      activejob (= 8.1.0.alpha)
      activesupport (= 8.1.0.alpha)
      mail (>= 2.8.0)
      rails-dom-testing (~> 2.2)
    actionpack (8.1.0.alpha)
      actionview (= 8.1.0.alpha)
      activesupport (= 8.1.0.alpha)
      nokogiri (>= 1.8.5)
      rack (>= 2.2.4)
      rack-session (>= 1.0.1)
      rack-test (>= 0.6.3)
      rails-dom-testing (~> 2.2)
      rails-html-sanitizer (~> 1.6)
      useragent (~> 0.16)
    actiontext (8.1.0.alpha)
      actionpack (= 8.1.0.alpha)
      activerecord (= 8.1.0.alpha)
      activestorage (= 8.1.0.alpha)
      activesupport (= 8.1.0.alpha)
      globalid (>= 0.6.0)
      nokogiri (>= 1.8.5)
    actionview (8.1.0.alpha)
      activesupport (= 8.1.0.alpha)
      builder (~> 3.1)
      erubi (~> 1.11)
      rails-dom-testing (~> 2.2)
      rails-html-sanitizer (~> 1.6)
    activejob (8.1.0.alpha)
      activesupport (= 8.1.0.alpha)
      globalid (>= 0.3.6)
    activemodel (8.1.0.alpha)
      activesupport (= 8.1.0.alpha)
    activerecord (8.1.0.alpha)
      activemodel (= 8.1.0.alpha)
      activesupport (= 8.1.0.alpha)
      timeout (>= 0.4.0)
    activestorage (8.1.0.alpha)
      actionpack (= 8.1.0.alpha)
      activejob (= 8.1.0.alpha)
      activerecord (= 8.1.0.alpha)
      activesupport (= 8.1.0.alpha)
      marcel (~> 1.0)
    activesupport (8.1.0.alpha)
      base64
      benchmark (>= 0.3)
      bigdecimal
      concurrent-ruby (~> 1.0, >= 1.3.1)
      connection_pool (>= 2.2.5)
      drb
      i18n (>= 1.6, < 2)
      logger (>= 1.4.2)
      minitest (>= 5.1)
      securerandom (>= 0.3)
      tzinfo (~> 2.0, >= 2.0.5)
      uri (>= 0.13.1)
    rails (8.1.0.alpha)
      actioncable (= 8.1.0.alpha)
      actionmailbox (= 8.1.0.alpha)
      actionmailer (= 8.1.0.alpha)
      actionpack (= 8.1.0.alpha)
      actiontext (= 8.1.0.alpha)
      actionview (= 8.1.0.alpha)
      activejob (= 8.1.0.alpha)
      activemodel (= 8.1.0.alpha)
      activerecord (= 8.1.0.alpha)
      activestorage (= 8.1.0.alpha)
      activesupport (= 8.1.0.alpha)
      bundler (>= 1.15.0)
      railties (= 8.1.0.alpha)
    railties (8.1.0.alpha)
      actionpack (= 8.1.0.alpha)
      activesupport (= 8.1.0.alpha)
      irb (~> 1.13)
      rackup (>= 1.0.0)
      rake (>= 12.2)
      thor (~> 1.0, >= 1.2.2)
      zeitwerk (~> 2.6)

PATH
  remote: tools/releaser
  specs:
    releaser (1.0.0)
      minitest
      rake (~> 13.0)

GEM
  remote: https://rubygems.org/
  specs:
    addressable (2.8.7)
      public_suffix (>= 2.0.2, < 7.0)
    amq-protocol (2.3.2)
    ast (2.4.2)
    aws-eventstream (1.3.0)
    aws-partitions (1.1037.0)
    aws-sdk-core (3.215.1)
      aws-eventstream (~> 1, >= 1.3.0)
      aws-partitions (~> 1, >= 1.992.0)
      aws-sigv4 (~> 1.9)
      jmespath (~> 1, >= 1.6.1)
    aws-sdk-kms (1.96.0)
      aws-sdk-core (~> 3, >= 3.210.0)
      aws-sigv4 (~> 1.5)
    aws-sdk-s3 (1.177.0)
      aws-sdk-core (~> 3, >= 3.210.0)
      aws-sdk-kms (~> 1)
      aws-sigv4 (~> 1.5)
    aws-sdk-sns (1.92.0)
      aws-sdk-core (~> 3, >= 3.210.0)
      aws-sigv4 (~> 1.5)
    aws-sigv4 (1.11.0)
      aws-eventstream (~> 1, >= 1.0.2)
    azure-storage-blob (2.0.3)
      azure-storage-common (~> 2.0)
      nokogiri (~> 1, >= 1.10.8)
    azure-storage-common (2.0.4)
      faraday (~> 1.0)
      faraday_middleware (~> 1.0, >= 1.0.0.rc1)
      net-http-persistent (~> 4.0)
      nokogiri (~> 1, >= 1.10.8)
    backburner (1.6.1)
      beaneater (~> 1.0)
      concurrent-ruby (~> 1.0, >= 1.0.1)
      dante (> 0.1.5)
    base64 (0.2.0)
    bcrypt (3.1.20)
    bcrypt_pbkdf (1.1.1)
    beaneater (1.1.3)
    benchmark (0.4.0)
    bigdecimal (3.1.9)
    bindex (0.8.1)
    bootsnap (1.18.4)
      msgpack (~> 1.2)
    brakeman (7.0.0)
      racc
    builder (3.3.0)
    bunny (2.23.0)
      amq-protocol (~> 2.3, >= 2.3.1)
      sorted_set (~> 1, >= 1.0.2)
    capybara (3.40.0)
      addressable
      matrix
      mini_mime (>= 0.1.3)
      nokogiri (~> 1.11)
      rack (>= 1.6.0)
      rack-test (>= 0.6.3)
      regexp_parser (>= 1.5, < 3.0)
      xpath (~> 3.2)
    chef-utils (18.6.2)
      concurrent-ruby
    childprocess (5.1.0)
      logger (~> 1.5)
    concurrent-ruby (1.3.4)
    connection_pool (2.5.0)
    crack (1.0.0)
      bigdecimal
      rexml
    crass (1.0.6)
    cssbundling-rails (1.4.1)
      railties (>= 6.0.0)
    dalli (3.2.8)
    dante (0.2.0)
    dartsass-rails (0.5.1)
      railties (>= 6.0.0)
      sass-embedded (~> 1.63)
    date (3.4.1)
    debug (1.10.0)
      irb (~> 1.10)
      reline (>= 0.3.8)
    declarative (0.0.20)
    digest-crc (0.6.5)
      rake (>= 12.0.0, < 14.0.0)
    dotenv (3.1.7)
    drb (2.2.1)
    ed25519 (1.3.0)
    erubi (1.13.1)
    et-orbi (1.2.11)
      tzinfo
    event_emitter (0.2.6)
    execjs (2.10.0)
    faraday (1.10.4)
      faraday-em_http (~> 1.0)
      faraday-em_synchrony (~> 1.0)
      faraday-excon (~> 1.1)
      faraday-httpclient (~> 1.0)
      faraday-multipart (~> 1.0)
      faraday-net_http (~> 1.0)
      faraday-net_http_persistent (~> 1.0)
      faraday-patron (~> 1.0)
      faraday-rack (~> 1.0)
      faraday-retry (~> 1.0)
      ruby2_keywords (>= 0.0.4)
    faraday-em_http (1.0.0)
    faraday-em_synchrony (1.0.0)
    faraday-excon (1.1.0)
    faraday-httpclient (1.0.1)
    faraday-multipart (1.1.0)
      multipart-post (~> 2.0)
    faraday-net_http (1.0.2)
    faraday-net_http_persistent (1.2.0)
    faraday-patron (1.0.0)
    faraday-rack (1.0.0)
    faraday-retry (1.0.3)
    faraday_middleware (1.2.1)
      faraday (~> 1.0)
    ffi (1.17.1)
    ffi (1.17.1-x86_64-darwin)
    ffi (1.17.1-x86_64-linux-gnu)
    fugit (1.11.1)
      et-orbi (~> 1, >= 1.2.11)
      raabro (~> 1.4)
    globalid (1.2.1)
      activesupport (>= 6.1)
    google-apis-core (0.15.1)
      addressable (~> 2.5, >= 2.5.1)
      googleauth (~> 1.9)
      httpclient (>= 2.8.3, < 3.a)
      mini_mime (~> 1.0)
      mutex_m
      representable (~> 3.0)
      retriable (>= 2.0, < 4.a)
    google-apis-iamcredentials_v1 (0.22.0)
      google-apis-core (>= 0.15.0, < 2.a)
    google-apis-storage_v1 (0.49.0)
      google-apis-core (>= 0.15.0, < 2.a)
    google-cloud-core (1.7.1)
      google-cloud-env (>= 1.0, < 3.a)
      google-cloud-errors (~> 1.0)
    google-cloud-env (2.2.1)
      faraday (>= 1.0, < 3.a)
    google-cloud-errors (1.4.0)
    google-cloud-storage (1.54.0)
      addressable (~> 2.8)
      digest-crc (~> 0.4)
      google-apis-core (~> 0.13)
      google-apis-iamcredentials_v1 (~> 0.18)
      google-apis-storage_v1 (~> 0.38)
      google-cloud-core (~> 1.6)
      googleauth (~> 1.9)
      mini_mime (~> 1.0)
    google-logging-utils (0.1.0)
    google-protobuf (4.29.3)
      bigdecimal
      rake (>= 13)
    google-protobuf (4.29.3-x86_64-darwin)
      bigdecimal
      rake (>= 13)
    google-protobuf (4.29.3-x86_64-linux)
      bigdecimal
      rake (>= 13)
    googleauth (1.12.2)
      faraday (>= 1.0, < 3.a)
      google-cloud-env (~> 2.2)
      google-logging-utils (~> 0.1)
      jwt (>= 1.4, < 3.0)
      multi_json (~> 1.11)
      os (>= 0.9, < 2.0)
      signet (>= 0.16, < 2.a)
    hashdiff (1.1.2)
    i18n (1.14.6)
      concurrent-ruby (~> 1.0)
    image_processing (1.13.0)
      mini_magick (>= 4.9.5, < 5)
      ruby-vips (>= 2.0.17, < 3)
    importmap-rails (2.1.0)
      actionpack (>= 6.0.0)
      activesupport (>= 6.0.0)
      railties (>= 6.0.0)
    io-console (0.8.0)
    irb (1.14.3)
      rdoc (>= 4.0.0)
      reline (>= 0.4.2)
    jbuilder (2.13.0)
      actionview (>= 5.0.0)
      activesupport (>= 5.0.0)
    jmespath (1.6.2)
    jsbundling-rails (1.3.1)
      railties (>= 6.0.0)
    json (2.9.1)
    jwt (2.10.1)
      base64
    kamal (2.4.0)
      activesupport (>= 7.0)
      base64 (~> 0.2)
      bcrypt_pbkdf (~> 1.0)
      concurrent-ruby (~> 1.2)
      dotenv (~> 3.1)
      ed25519 (~> 1.2)
      net-ssh (~> 7.3)
      sshkit (>= 1.23.0, < 2.0)
      thor (~> 1.3)
      zeitwerk (>= 2.6.18, < 3.0)
    kramdown (2.5.1)
      rexml (>= 3.3.9)
    kramdown-parser-gfm (1.1.0)
      kramdown (~> 2.0)
    language_server-protocol (3.17.0.3)
    launchy (3.0.1)
      addressable (~> 2.8)
      childprocess (~> 5.0)
    libxml-ruby (5.0.3)
    listen (3.9.0)
      rb-fsevent (~> 0.10, >= 0.10.3)
      rb-inotify (~> 0.9, >= 0.9.10)
    logger (1.6.5)
    loofah (2.24.0)
      crass (~> 1.0.2)
      nokogiri (>= 1.12.0)
    mail (2.8.1)
      mini_mime (>= 0.1.1)
      net-imap
      net-pop
      net-smtp
    marcel (1.0.4)
    matrix (0.4.2)
    mdl (0.12.0)
      kramdown (~> 2.3)
      kramdown-parser-gfm (~> 1.1)
      mixlib-cli (~> 2.1, >= 2.1.1)
      mixlib-config (>= 2.2.1, < 4)
      mixlib-shellout
    mini_magick (4.13.2)
    mini_mime (1.1.5)
    mini_portile2 (2.8.8)
    minitest (5.25.4)
    minitest-bisect (1.7.0)
      minitest-server (~> 1.0)
      path_expander (~> 1.1)
    minitest-ci (3.4.0)
      minitest (>= 5.0.6)
    minitest-retry (0.2.3)
      minitest (>= 5.0)
    minitest-server (1.0.8)
      drb (~> 2.0)
      minitest (~> 5.16)
    mixlib-cli (2.1.8)
    mixlib-config (3.0.27)
      tomlrb
    mixlib-shellout (3.3.4)
      chef-utils
    mono_logger (1.1.2)
    msgpack (1.7.5)
    multi_json (1.15.0)
    multipart-post (2.4.1)
    mustermann (3.0.3)
      ruby2_keywords (~> 0.0.1)
    mutex_m (0.3.0)
    mysql2 (0.5.6)
    net-http-persistent (4.0.5)
      connection_pool (~> 2.2)
    net-imap (0.5.5)
      date
      net-protocol
    net-pop (0.1.2)
      net-protocol
    net-protocol (0.2.2)
      timeout
    net-scp (4.0.0)
      net-ssh (>= 2.6.5, < 8.0.0)
    net-sftp (4.0.0)
      net-ssh (>= 5.0.0, < 8.0.0)
    net-smtp (0.5.0)
      net-protocol
    net-ssh (7.3.0)
    nio4r (2.7.4)
    nokogiri (1.18.1)
      mini_portile2 (~> 2.8.2)
      racc (~> 1.4)
    nokogiri (1.18.1-x86_64-darwin)
      racc (~> 1.4)
    nokogiri (1.18.1-x86_64-linux-gnu)
      racc (~> 1.4)
    os (1.1.4)
    ostruct (0.6.1)
    parallel (1.26.3)
    parser (3.3.6.0)
      ast (~> 2.4.1)
      racc
    path_expander (1.1.3)
    pg (1.5.9)
    prism (1.3.0)
    propshaft (1.1.0)
      actionpack (>= 7.0.0)
      activesupport (>= 7.0.0)
      rack
      railties (>= 7.0.0)
    psych (5.2.2)
      date
      stringio
    public_suffix (6.0.1)
    puma (6.5.0)
      nio4r (~> 2.0)
    queue_classic (4.0.0)
      pg (>= 1.1, < 2.0)
    raabro (1.4.0)
    racc (1.8.1)
    rack (3.1.8)
    rack-cache (1.17.0)
      rack (>= 0.4)
    rack-protection (4.1.1)
      base64 (>= 0.1.0)
      logger (>= 1.6.0)
      rack (>= 3.0.0, < 4)
    rack-session (2.1.0)
      base64 (>= 0.1.0)
      rack (>= 3.0.0)
    rack-test (2.2.0)
      rack (>= 1.3)
    rackup (2.2.1)
      rack (>= 3)
    rails-dom-testing (2.2.0)
      activesupport (>= 5.0.0)
      minitest
      nokogiri (>= 1.6)
    rails-html-sanitizer (1.6.2)
      loofah (~> 2.21)
      nokogiri (>= 1.15.7, != 1.16.7, != 1.16.6, != 1.16.5, != 1.16.4, != 1.16.3, != 1.16.2, != 1.16.1, != 1.16.0.rc1, != 1.16.0)
    rainbow (3.1.1)
    rake (13.2.1)
    rb-fsevent (0.11.2)
    rb-inotify (0.11.1)
      ffi (~> 1.0)
    rbtree (0.4.6)
    rdoc (6.9.1)
      psych (>= 4.0.0)
    redcarpet (3.2.3)
    redis (5.3.0)
      redis-client (>= 0.22.0)
    redis-client (0.23.1)
      connection_pool
    redis-namespace (1.11.0)
      redis (>= 4)
    regexp_parser (2.10.0)
    reline (0.6.0)
      io-console (~> 0.5)
    representable (3.2.0)
      declarative (< 0.1.0)
      trailblazer-option (>= 0.1.1, < 0.2.0)
      uber (< 0.2.0)
    resque (2.7.0)
      mono_logger (~> 1)
      multi_json (~> 1.0)
      redis-namespace (~> 1.6)
      sinatra (>= 0.9.2)
    resque-scheduler (4.11.0)
      mono_logger (~> 1.0)
      redis (>= 3.3)
      resque (>= 1.27)
      rufus-scheduler (~> 3.2, != 3.3)
    retriable (3.1.2)
    rexml (3.4.0)
    rouge (4.5.1)
    rubocop (1.70.0)
      json (~> 2.3)
      language_server-protocol (>= 3.17.0)
      parallel (~> 1.10)
      parser (>= 3.3.0.2)
      rainbow (>= 2.2.2, < 4.0)
      regexp_parser (>= 2.9.3, < 3.0)
      rubocop-ast (>= 1.36.2, < 2.0)
      ruby-progressbar (~> 1.7)
      unicode-display_width (>= 2.4.0, < 4.0)
    rubocop-ast (1.37.0)
      parser (>= 3.3.1.0)
    rubocop-md (1.2.4)
      rubocop (>= 1.45)
    rubocop-minitest (0.36.0)
      rubocop (>= 1.61, < 2.0)
      rubocop-ast (>= 1.31.1, < 2.0)
    rubocop-packaging (0.5.2)
      rubocop (>= 1.33, < 2.0)
    rubocop-performance (1.23.1)
      rubocop (>= 1.48.1, < 2.0)
      rubocop-ast (>= 1.31.1, < 2.0)
    rubocop-rails (2.28.0)
      activesupport (>= 4.2.0)
      rack (>= 1.1)
      rubocop (>= 1.52.0, < 2.0)
      rubocop-ast (>= 1.31.1, < 2.0)
    rubocop-rails-omakase (1.0.0)
      rubocop
      rubocop-minitest
      rubocop-performance
      rubocop-rails
    ruby-progressbar (1.13.0)
    ruby-vips (2.2.2)
      ffi (~> 1.12)
      logger
    ruby2_keywords (0.0.5)
    rubyzip (2.4.1)
    rufus-scheduler (3.9.2)
      fugit (~> 1.1, >= 1.11.1)
    sass-embedded (1.83.4)
      google-protobuf (~> 4.29)
      rake (>= 13)
    sass-embedded (1.83.4-x86_64-darwin)
      google-protobuf (~> 4.29)
    sass-embedded (1.83.4-x86_64-linux-gnu)
      google-protobuf (~> 4.29)
    securerandom (0.4.1)
    selenium-webdriver (4.27.0)
      base64 (~> 0.2)
      logger (~> 1.4)
      rexml (~> 3.2, >= 3.2.5)
      rubyzip (>= 1.2.2, < 3.0)
      websocket (~> 1.0)
    serverengine (2.0.7)
      sigdump (~> 0.2.2)
    set (1.1.1)
    sidekiq (7.3.7)
      connection_pool (>= 2.3.0)
      logger
      rack (>= 2.2.4)
      redis-client (>= 0.22.2)
    sigdump (0.2.5)
    signet (0.19.0)
      addressable (~> 2.8)
      faraday (>= 0.17.5, < 3.a)
      jwt (>= 1.5, < 3.0)
      multi_json (~> 1.10)
    sinatra (4.1.1)
      logger (>= 1.6.0)
      mustermann (~> 3.0)
      rack (>= 3.0.0, < 4)
      rack-protection (= 4.1.1)
      rack-session (>= 2.0.0, < 3)
      tilt (~> 2.0)
    sneakers (2.11.0)
      bunny (~> 2.12)
      concurrent-ruby (~> 1.0)
      rake
      serverengine (~> 2.0.5)
      thor
    solid_cable (3.0.5)
      actioncable (>= 7.2)
      activejob (>= 7.2)
      activerecord (>= 7.2)
      railties (>= 7.2)
    solid_cache (1.0.6)
      activejob (>= 7.2)
      activerecord (>= 7.2)
      railties (>= 7.2)
    solid_queue (1.1.2)
      activejob (>= 7.1)
      activerecord (>= 7.1)
      concurrent-ruby (>= 1.3.1)
      fugit (~> 1.11.0)
      railties (>= 7.1)
      thor (~> 1.3.1)
    sorted_set (1.0.3)
      rbtree
      set (~> 1.0)
    sprockets (4.2.1)
      concurrent-ruby (~> 1.0)
      rack (>= 2.2.4, < 4)
    sprockets-rails (3.5.2)
      actionpack (>= 6.1)
      activesupport (>= 6.1)
      sprockets (>= 3.0.0)
    sqlite3 (2.5.0)
      mini_portile2 (~> 2.8.0)
    sqlite3 (2.5.0-x86_64-darwin)
    sqlite3 (2.5.0-x86_64-linux-gnu)
    sshkit (1.23.2)
      base64
      net-scp (>= 1.1.2)
      net-sftp (>= 2.1.2)
      net-ssh (>= 2.8.0)
      ostruct
    stackprof (0.2.27)
    stimulus-rails (1.3.4)
      railties (>= 6.0.0)
    stringio (3.1.2)
    sucker_punch (3.2.0)
      concurrent-ruby (~> 1.0)
    tailwindcss-rails (3.2.0)
      railties (>= 7.0.0)
      tailwindcss-ruby
    tailwindcss-ruby (3.4.17)
    tailwindcss-ruby (3.4.17-x86_64-darwin)
    tailwindcss-ruby (3.4.17-x86_64-linux)
    terser (1.2.4)
      execjs (>= 0.3.0, < 3)
    thor (1.3.2)
    thruster (0.1.10)
    thruster (0.1.10-x86_64-darwin)
    thruster (0.1.10-x86_64-linux)
    tilt (2.6.0)
    timeout (0.4.3)
    tomlrb (2.0.3)
    trailblazer-option (0.1.2)
    trilogy (2.9.0)
    turbo-rails (2.0.11)
      actionpack (>= 6.0.0)
      railties (>= 6.0.0)
    tzinfo (2.0.6)
      concurrent-ruby (~> 1.0)
    uber (0.1.0)
    unicode-display_width (3.1.4)
      unicode-emoji (~> 4.0, >= 4.0.4)
    unicode-emoji (4.0.4)
    uri (1.0.2)
    useragent (0.16.11)
    w3c_validators (1.3.7)
      json (>= 1.8)
      nokogiri (~> 1.6)
      rexml (~> 3.2)
    web-console (4.2.1)
      actionview (>= 6.0.0)
      activemodel (>= 6.0.0)
      bindex (>= 0.4.0)
      railties (>= 6.0.0)
    webmock (3.24.0)
      addressable (>= 2.8.0)
      crack (>= 0.3.2)
      hashdiff (>= 0.4.0, < 2.0.0)
    webrick (1.9.1)
    websocket (1.2.11)
    websocket-client-simple (0.9.0)
      base64
      event_emitter
      mutex_m
      websocket
    websocket-driver (0.7.7)
      base64
      websocket-extensions (>= 0.1.0)
    websocket-extensions (0.1.5)
    xpath (3.2.0)
      nokogiri (~> 1.8)
    zeitwerk (2.7.1)

PLATFORMS
  ruby
  x86_64-darwin
  x86_64-linux

DEPENDENCIES
  aws-sdk-s3
  aws-sdk-sns
  azure-storage-blob (~> 2.0)
  backburner
  bcrypt (~> 3.1.11)
  bootsnap (>= 1.4.4)
  brakeman
  capybara (>= 3.39)
  connection_pool
  cssbundling-rails
  dalli (>= 3.0.1)
  dartsass-rails
  debug (>= 1.1.0)
  google-cloud-storage (~> 1.11)
  httpclient!
  image_processing (~> 1.2)
  importmap-rails (>= 1.2.3)
  jbuilder
  jsbundling-rails
  json (>= 2.0.0, != 2.7.0)
  kamal (>= 2.1.0)
  launchy
  libxml-ruby
  listen (~> 3.3)
  mdl (!= 0.13.0)
  minitest
  minitest-bisect
  minitest-ci
  minitest-retry
  msgpack (>= 1.7.0)
  mysql2 (~> 0.5)
  nokogiri (>= 1.8.1, != 1.11.0)
  pg (~> 1.3)
  prism
  propshaft (>= 0.1.7, != 1.0.1)
  puma (>= 5.0.3)
  queue_classic (>= 4.0.0)
  rack (~> 3.0)
  rack-cache (~> 1.2)
  rails!
  rake (>= 13)
  rdoc (< 6.10)
  redcarpet (~> 3.2.3)
  redis (>= 4.0.1)
  redis-namespace
  releaser!
  resque
  resque-scheduler
  rexml
  rouge
  rubocop (>= 1.25.1)
  rubocop-md
  rubocop-minitest
  rubocop-packaging
  rubocop-performance
  rubocop-rails
  rubocop-rails-omakase
  rubyzip (~> 2.0)
  sdoc!
  selenium-webdriver (>= 4.20.0)
  sidekiq
  sneakers
  solid_cable
  solid_cache
  solid_queue
  sprockets-rails (>= 2.0.0)
  sqlite3 (>= 2.1)
  stackprof
  stimulus-rails
  sucker_punch
  tailwindcss-rails
  terser (>= 1.1.4)
  thruster
  trilogy (>= 2.7.0)
  turbo-rails
  tzinfo-data
  uri (>= 0.13.1)
  useragent
  w3c_validators (~> 1.3.6)
  wdm (>= 0.1.0)
  web-console
  webmock
  webrick
  websocket-client-simple

BUNDLED WITH
   2.5.16
