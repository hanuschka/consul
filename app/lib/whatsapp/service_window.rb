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
  def deliverable?(account, kind)
    return true if open?(account)

    Rails.logger.info(
      "[Whatsapp] skipped #{kind} to account #{account.id}: service window closed"
    )

    false
  end
end
