class Whatsapp::Flows::ConfirmUnlinkService < ApplicationService
  # Catalog A7, second half. The confirmation is sent before the account row is
  # cleared, not after: an unlinked number is outside the service window's
  # notion of a linked citizen, and sending afterwards risks the citizen being
  # told nothing at all about the thing they just asked for.
  def initialize(conversation:)
    @conversation = conversation
  end

  def call
    Whatsapp::Outbound.text(
      account: @conversation.whatsapp_account,
      body: I18n.t("whatsapp.bot.onboarding.unlinked")
    )

    @conversation.reset_flow!
    @conversation.whatsapp_account.unlink!
  end
end
