class Whatsapp::ConfirmLinkReplyJob < ApplicationJob
  queue_as :default

  # The two messages that follow a successful link, sent out of the request
  # that confirmed it. Both are Graph API calls behind a 20-second timeout and
  # three retries, so leaving them inline held a Puma thread for up to two
  # minutes on a page the citizen is waiting on.
  def perform(whatsapp_account_id)
    account = WhatsappAccount.find_by(id: whatsapp_account_id)

    return if account.blank?
    return if !::Whatsapp.enabled?

    I18n.with_locale(locale_for(account)) do
      Whatsapp::Outbound.text(
        account: account,
        body: I18n.t("whatsapp.bot.link_confirmed", name: account.user&.name)
      )

      Whatsapp::NextStepService.call(conversation: account.conversation)
    end
  end

  private

    def locale_for(account)
      user_locale = account.user&.locale.to_s

      return ::Whatsapp.default_locale if !I18n.available_locales.map(&:to_s).include?(user_locale)

      user_locale
    end
end
