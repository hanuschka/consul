class Whatsapp::RefreshPhrasingJob < ApplicationJob
  queue_as :default

  # Fills the phrase set the bot reads its routine prose from. It runs here
  # rather than in the request because generating all of it is one completion
  # of several seconds, and the message that found the cache empty is usually
  # the "one moment" line itself — a citizen would have waited out the whole
  # generation before seeing the reply telling them to wait.
  #
  # Nothing depends on it finishing: PhrasingService answers from the locale
  # file whenever the set is missing, so a failure here costs variety and
  # nothing else.
  def perform(locale)
    return if !::Whatsapp.enabled?

    Whatsapp::AiAssistant::PhrasingService.refresh(locale: locale)
  rescue StandardError => e
    Rails.logger.error("[Whatsapp] phrasing refresh failed: #{e.class} - #{e.message}")

    Sentry.capture_exception(e)
  end
end
