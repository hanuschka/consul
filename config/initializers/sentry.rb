Sentry.init do |config|
  config.dsn = Rails.application.secrets.sentry_key
  config.breadcrumbs_logger = [:active_support_logger]
  # config.rails.report_rescued_exceptions = true
  config.excluded_exceptions += ["FeatureFlags::FeatureDisabled", "SignalException"]

  config.before_send = lambda do |event, hint|
    exception = hint[:exception]
    if exception.is_a?(ArgumentError) && exception.message.include?("combine_options")
      nil
    else
      event
    end
  end

  # To activate performance monitoring, set one of these options.
  # We recommend adjusting the value in production:
  config.traces_sample_rate = 1.0
  # or
  config.traces_sampler = lambda do |context|
    true
  end
end
