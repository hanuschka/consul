module Whatsapp::ServiceWindow
  module_function

  # WhatsApp only accepts free-form messages while the recipient has written in
  # the last 24 hours (error 131047 otherwise); outside it, only an approved
  # template may reopen the conversation.
  def open?(account)
    account.last_inbound_at.present? && account.last_inbound_at > ::Whatsapp::SERVICE_WINDOW.ago
  end

  # Guard for the free-form senders: refusing here keeps a message the API would
  # reject anyway out of the dialog history and out of the error budget.
  #
  # Warned rather than noted, because reaching this is a reply that was composed
  # and then dropped. The inbound side declines to answer a delivery that
  # arrived past the window at all, so what is left here is the case that should
  # not happen — a reply to a conversation whose window shut while the turn was
  # still running, or a send from a path with no inbound message behind it.
  def deliverable?(account, kind)
    return true if open?(account)

    Rails.logger.warn(
      "[Whatsapp] skipped #{kind} to account #{account.id}: service window closed"
    )

    false
  end
end
