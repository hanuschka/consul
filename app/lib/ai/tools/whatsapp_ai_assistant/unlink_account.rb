class Ai::Tools::WhatsappAiAssistant::UnlinkAccount < Ai::Tools::WhatsappAiAssistant::BaseTool
  # Severing the link cannot be undone from the chat — the number keeps nothing about
  # who was behind it — so the confirmation is a precondition rather than a
  # convention: this refuses until the citizen has been asked, and being asked is the
  # `unlink_confirm` button having been offered.
  #
  # Which is now also what proves they were told the truth about it. The pill is
  # withheld from the assistant entirely
  # (Whatsapp::FlowActions::PLATFORM_WORDED_ACTIONS), so the only thing that can have
  # offered it is ShowUnlinkForConfirmation, and that tool sends the fixed statement
  # in the same breath. What used to be a precondition on the question being asked is
  # a precondition on the right question having been asked.
  description "Disconnects this number from the citizen's portal account. It cannot be undone " \
              "from here: the number keeps nothing about who was behind it, and they would have " \
              "to link again from scratch. What unlinking does and does not do is stated by the " \
              "platform and not by you, so never describe it in your own words: call " \
              "show_unlink_for_confirmation, which sends that statement and offers the " \
              "unlink_confirm button, and this refuses until that button has been offered in " \
              "this conversation. Never call it straight off their first mention of unlinking. " \
              "It sends the confirmation itself, because a number that has just been unlinked " \
              "may no longer be reachable afterwards."

  def diagnostic_step
    ::Whatsapp::Conversation::Step::AWAITING_UNLINK_CONFIRMATION
  end

  def execute
    return not_linked_answer if user.blank?
    return not_confirmed_error if !conversation.confirmation_offered?(:unlink_confirm)

    # Sent before the account row is cleared, not after: an unlinked number is
    # outside the service window's notion of a linked citizen, and sending afterwards
    # risks the citizen being told nothing at all about the thing they just asked for.
    #
    # With the way back under it. A number that has just been unlinked can still be
    # written to and still reaches the assistant, so the one thing the citizen must
    # not be left with is a farewell and a blank prompt.
    ::Whatsapp::Send.recovery(
      conversation: conversation,
      body: ::Whatsapp.copy(
        "whatsapp.bot.onboarding.unlinked",
        delete_account_url: ::Whatsapp::PortalLinks.delete_account_url
      ),
      actions: [:help]
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
      { error: "The citizen has not been asked to confirm this yet. Call " \
               "show_unlink_for_confirmation — it states what unlinking does and offers the " \
               "unlink_confirm button — and call this only after they have answered that " \
               "question. Do not write out what unlinking does yourself." }
    end
end
