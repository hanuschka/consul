class Whatsapp::ConfirmLinkReplyJob < ApplicationJob
  queue_as :default
  queue_with_priority ::Whatsapp::REPLY_PRIORITY

  # The messages that follow a link attempt, sent out of the request that made
  # it. Both are Graph API calls behind a 20-second timeout and three retries,
  # so leaving them inline held a Puma thread for up to two minutes on a page
  # the citizen is waiting on.
  #
  # The outcome is passed in rather than re-derived: by the time this runs the
  # token is already consumed, so the account row no longer says which of the
  # catalog's A4-A6 branches the citizen just hit.
  def perform(whatsapp_account_id, outcome = "linked")
    account = Whatsapp::Account.find_by(id: whatsapp_account_id)

    return if account.blank?
    return if !::Whatsapp.enabled?

    I18n.with_locale(::Whatsapp.locale_for(account)) do
      reply(account.conversation, outcome.to_s)
    end
  end

  private

    def reply(conversation, outcome)
      return Whatsapp::Accounts::LinkOutcomeService.confirmed(conversation: conversation) if
        outcome == "linked"

      Whatsapp::Accounts::LinkOutcomeService.error(conversation: conversation, reason: outcome)
    end
end
