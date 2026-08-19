class Whatsapp::Accounts::LinkOutcomeService < ApplicationService
  # What the citizen is told after they followed their login link on the portal.
  # Pushed out of Whatsapp::ConfirmLinkReplyJob rather than answered inside a
  # conversation turn, which is why it keeps the locale copy: there is no inbound
  # message here for an assistant to be answering, and the citizen is standing in
  # a browser waiting to be told whether it worked.
  #
  # Plain text and no pills. What follows a successful link is whatever the
  # citizen writes next, and that reaches the assistant with the account already
  # attached.
  ERROR_REASONS = %w[no_account expired already_linked number_taken].freeze

  def self.confirmed(conversation:)
    new(conversation: conversation).confirmed
  end

  def self.error(conversation:, reason:)
    new(conversation: conversation).error(reason)
  end

  def initialize(conversation:)
    @conversation = conversation
  end

  def confirmed
    ::Whatsapp::Send.text(
      account: account, body: I18n.t("whatsapp.bot.onboarding.linked")
    )
  end

  def error(reason)
    key = ERROR_REASONS.include?(reason.to_s) ? reason.to_s : "expired"

    ::Whatsapp::Send.text(
      account: account,
      body: I18n.t(
        "whatsapp.bot.onboarding.#{key}", register_url: ::Whatsapp::PortalLinks.register_url
      )
    )
  end

  private

    def account
      @conversation.whatsapp_account
    end
end
