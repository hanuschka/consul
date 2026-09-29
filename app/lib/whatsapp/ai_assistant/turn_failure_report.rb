module Whatsapp::AiAssistant::TurnFailureReport
  # Every turn that ends in the "I can't answer you right now" line, in error
  # monitoring. An exception always reached it; the failures that raise nothing did
  # not — a reply that came back empty, a reply WhatsApp refused, a tenant whose AI is
  # switched off — so a citizen could be left under that line after their comment went
  # in, and the only trace was one info line in the log.
  #
  # One fingerprint per reason rather than Sentry's own grouping: a message has no
  # stacktrace to group by, and without it every conversation would open an issue of
  # its own. What is worth watching is how often each reason happens, which is one
  # issue with a count.
  #
  # The completed actions travel with every report, because a failure after the
  # comment is on the page is not the same failure as one before anything happened,
  # and nothing else in the event would say which it was.
  FINGERPRINT = "whatsapp-assistant-turn-failed".freeze

  module_function

  # Never raises: this watches the turn, it is not part of it. A report that fails
  # costs the report, not the line the citizen is about to be sent.
  def exception(error, conversation:, **details)
    Rails.logger.error("[Whatsapp] assistant routing failed: #{error.class} - #{error.message}")

    Sentry.capture_exception(error, extra: extra_for(conversation, details))
  rescue StandardError => e
    Rails.logger.error("[Whatsapp] turn failure report failed: #{e.class} - #{e.message}")
  end

  def message(reason:, conversation:, level: :error, **details)
    Rails.logger.error("[Whatsapp] assistant turn ended in the fallback: #{reason}")

    Sentry.capture_message(
      "WhatsApp assistant turn ended in the fallback: #{reason}",
      level: level,
      fingerprint: [FINGERPRINT, reason.to_s],
      extra: extra_for(conversation, details)
    )
  rescue StandardError => e
    Rails.logger.error("[Whatsapp] turn failure report failed: #{e.class} - #{e.message}")
  end

  def extra_for(conversation, details)
    {
      whatsapp_conversation_id: conversation&.id,
      completed_actions: conversation&.completed_actions&.map(&:kind)&.join(",").presence
    }.merge(details).compact
  end
end
