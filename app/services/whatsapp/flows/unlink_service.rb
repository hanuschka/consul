class Whatsapp::Flows::UnlinkService < ApplicationService
  # Catalog A7, first half. Unlinking is self-service but never one tap: the
  # confirmation names what is lost, because the number is deleted immediately
  # afterwards and there is nothing to undo it with.
  def initialize(conversation:)
    @conversation = conversation
  end

  def call
    @conversation.update!(step: "awaiting_unlink_confirmation")

    Whatsapp::Outbound.buttons(
      account: @conversation.whatsapp_account,
      body: I18n.t("whatsapp.bot.onboarding.unlink_confirm"),
      buttons: buttons
    )
  end

  private

    def buttons
      [
        Whatsapp::FlowActions.button(
          action: :unlink_confirm, label_key: "whatsapp.bot.buttons.unlink_yes"
        ),
        Whatsapp::FlowActions.button(
          action: :unlink_cancel, label_key: "whatsapp.bot.buttons.cancel"
        )
      ]
    end
end
