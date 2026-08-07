class Whatsapp::ConfirmLinkReplyJob < ApplicationJob
  queue_as :default

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

    I18n.with_locale(locale_for(account)) do
      reply(account.conversation, outcome.to_s)
    end
  end

  private

    def reply(conversation, outcome)
      return Whatsapp::Flows::LinkConfirmedService.call(conversation: conversation) if
        outcome == "linked"

      Whatsapp::Flows::LinkErrorService.call(conversation: conversation, reason: outcome)
    end

    def locale_for(account)
      user_locale = account.user&.locale.to_s

      return ::Whatsapp.default_locale if !I18n.available_locales.map(&:to_s).include?(user_locale)

      user_locale
    end
end
