Sentry.init do |config|
  config.dsn = 'https://ae87de89cb154acc9e4b3b77f35efb96@o994111.ingest.sentry.io/5952564'
  config.breadcrumbs_logger = [:active_support_logger]

  # To activate performance monitoring, set one of these options.
  # We recommend adjusting the value in production:
  config.traces_sample_rate = 1.0
  # or
  config.traces_sampler = lambda do |context|
    true
  end
end
