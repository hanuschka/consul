Sentry.init do |config|
  config.dsn = 'https://d7ce28d5094a4c91851f66dadf8dd7ff@o994111.ingest.sentry.io/5952592'
  config.breadcrumbs_logger = [:active_support_logger]

  # To activate performance monitoring, set one of these options.
  # We recommend adjusting the value in production:
  config.traces_sample_rate = 1.0
  # or
  config.traces_sampler = lambda do |context|
    true
  end
end
