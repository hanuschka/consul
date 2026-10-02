module Whatsapp::SignatureRefusal
  module_function

  # The last delivery refused for its signature alone — one that carried the
  # shared secret, so it is known to come from 360dialog. Kept apart from every
  # other refusal on purpose: a stray request failing the header check says
  # nothing about the account, and recording those would raise the alarm on
  # every scanner. A header that does not match is caught by the webhook status
  # check instead, which reads the registration back from 360dialog.
  CACHE_KEY = "whatsapp/signature_refusal".freeze
  THROTTLE = 1.minute

  def record(reason)
    latest = Rails.cache.read(CACHE_KEY)

    return if latest.present? && latest[:reason] == reason && latest[:at] > THROTTLE.ago

    Rails.cache.write(
      CACHE_KEY,
      { reason: reason, at: Time.current, fingerprint: ::Whatsapp.credentials_fingerprint },
      expires_in: ::Whatsapp::WEBHOOK_EVENT_RETENTION
    )
  end

  # The reason while it still stands: nothing has been accepted since, and the
  # credentials are the ones it was refused under. Editing them is the fix, so
  # a change hides the reason until a delivery fails again.
  def unresolved_reason
    latest = Rails.cache.read(CACHE_KEY)

    return if latest.blank?
    return if latest[:fingerprint] != ::Whatsapp.credentials_fingerprint
    return if accepted_since?(latest[:at])

    latest[:reason]
  end

  def accepted_since?(time)
    last_accepted_at = ::Whatsapp::WebhookEvent.maximum(:created_at)

    last_accepted_at.present? && last_accepted_at > time
  end
end
