class Ai::Tools::WhatsappAiAssistant::UnlinkAccount < Ai::Tools::WhatsappAiAssistant::BaseTool
  # Severing the link cannot be undone from the chat — the number keeps nothing about
  # who was behind it — so the confirmation is a precondition rather than a
  # convention: this refuses until the citizen has been asked, and being asked is the
  # `unlink_confirm` button having been offered.
  description "Disconnects this number from the citizen's portal account. It cannot be undone " \
              "from here: everything the number knew about them is cleared, and they would have " \
              "to link again from scratch. So ask them first, in your own words, naming what is " \
              "lost, and offer the unlink_confirm button — this refuses until that button has " \
              "been offered in this conversation, so never call it straight off their first " \
              "mention of unlinking. It sends the confirmation itself, because a number that has " \
              "just been unlinked may no longer be reachable afterwards."

  def diagnostic_step
    ::Whatsapp::Conversation::Step::AWAITING_UNLINK_CONFIRMATION
  end

  def execute
    return not_linked_answer if user.blank?
    return not_confirmed_error if !conversation.confirmation_offered?(:unlink_confirm)

    # Sent before the account row is cleared, not after: an unlinked number is
    # outside the service window's notion of a linked citizen, and sending afterwards
    # risks the citizen being told nothing at all about the thing they just asked for.
    ::Whatsapp::Send.locale_text(
      account: account, body: I18n.t("whatsapp.bot.onboarding.unlinked")
    )

    conversation.discard_draft!
    account.unlink!

    halt("Unlinked the account and confirmed it.")
  end

  private

    def not_linked_answer
      { error: "This number is not linked to an account, so there is nothing to unlink. Say so " \
               "rather than reporting a failure." }
    end

    # The precondition, and it is checked against what the bot's last message really
    # put in front of the citizen rather than against the model's own account of the
    # conversation: an assistant is perfectly capable of deciding it has already
    # confirmed something it only thought about, and this is the one action where
    # being wrong costs the citizen their account link with nothing to undo it.
    def not_confirmed_error
      { error: "The citizen has not been asked to confirm this yet. Tell them what unlinking " \
               "loses — the number would know nothing about them and they would have to link " \
               "again from scratch — and offer the unlink_confirm button. Call this only after " \
               "they have answered that question." }
    end
end
