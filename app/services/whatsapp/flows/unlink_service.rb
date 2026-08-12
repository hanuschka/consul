class Whatsapp::Flows::UnlinkService < Whatsapp::Flows::BaseService
  # Catalog A7, both halves. Unlinking is self-service but never one tap, so the
  # entry asks and the confirmation acts — two class methods over two instance
  # methods, the shape MessageDeliveryService uses for its own pair.
  def self.ask(conversation:)
    new(conversation: conversation).ask
  end

  def self.confirm(conversation:)
    new(conversation: conversation).confirm
  end

  # Names what is lost, because the link is cleared immediately afterwards and
  # there is nothing to undo it with.
  def ask
    @conversation.update!(step: "awaiting_unlink_confirmation")

    Whatsapp::Outbound.buttons(
      account: account,
      body: Whatsapp.phrase("whatsapp.bot.onboarding.unlink_confirm"),
      buttons: buttons
    )
  end

  # Sent before the account row is cleared, not after: an unlinked number is
  # outside the service window's notion of a linked citizen, and sending
  # afterwards risks the citizen being told nothing at all about the thing they
  # just asked for.
  def confirm
    Whatsapp::Outbound.text(
      account: account,
      body: Whatsapp.phrase("whatsapp.bot.onboarding.unlinked")
    )

    @conversation.reset_flow!
    account.unlink!
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
