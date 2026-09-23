# Keeps exception text out of the administrator's view. An LLM provider, a
# gem or Active Record words its errors for whoever wrote the call, not for the
# person running an import, and pasting that wording into the interface both
# confuses the admin and puts internals on screen. So the raw message goes to
# the log and to Sentry, and the interface shows only the fixed sentence stored
# under the given locale key.
module ProjektImports::FailureReporter
  ERROR_SCOPE = "adm.projekts.imports.errors".freeze
  WARNING_SCOPE = "adm.projekts.imports.warnings".freeze
  LOGGED_BACKTRACE_LINES = 10

  def self.error_message(error, source:, stage:, key:, sentry_context: {}, **interpolations)
    record(error, source: source, stage: stage, sentry_context: sentry_context)

    I18n.t("#{ERROR_SCOPE}.#{key}", **interpolations)
  end

  def self.warning_message(error, source:, stage:, key:, sentry_context: {}, **interpolations)
    record(error, source: source, stage: stage, sentry_context: sentry_context)

    I18n.t("#{WARNING_SCOPE}.#{key}", **interpolations)
  end

  # The backtrace is logged for every stage because the message alone no longer
  # reaches anyone who can act on it.
  def self.record(error, source:, stage:, sentry_context: {})
    backtrace = Array(error.backtrace).first(LOGGED_BACKTRACE_LINES).join("\n")

    Rails.logger.error(
      "[#{source}] #{stage} failed: #{error.class}: #{error.message}\n#{backtrace}"
    )

    return if !defined?(Sentry)

    Sentry.capture_exception(error, extra: sentry_context.merge(stage: stage))
  end
end
