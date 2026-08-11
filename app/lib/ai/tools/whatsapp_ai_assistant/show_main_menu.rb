class Ai::Tools::WhatsappAiAssistant::ShowMainMenu < Ai::Tools::WhatsappAiAssistant::BaseTool
  # Held apart from show_help, which lists everything the bot can do. This is
  # the three things a citizen starts from nothing, and it is the same menu the
  # flow sends after cancelling and after publishing — a greeting that landed
  # somewhere else would read as a fourth, different menu.
  #
  # It exists because reply_with_buttons cannot offer it: that tool is limited
  # to the recovery pills, so the best button it had for "Hallo" was Hilfe.
  description "Sends the main menu: submit a contribution, browse projects, my contributions. " \
              "Use it when the citizen greets you, says nothing specific, or asks what they can " \
              "do here — anything where the answer is the three starting points rather than a " \
              "particular one. This sends the message itself — do not write your own menu."

  # Refused mid-submission rather than guarded inside the menu: greeting resets
  # the flow, so sending it here would drop a draft the citizen is halfway
  # through. The deterministic greeting path makes the same check before it
  # answers "Hallo"; the model has no reason to know that, so it is told.
  def execute
    return submission_in_progress_error if conversation.drafting?

    ::Whatsapp::Flows::MainMenuService.greeting(conversation: conversation)

    halt("Sent the main menu.")
  end

  private

    def submission_in_progress_error
      { error: "This citizen is in the middle of a submission, and the menu would discard it. " \
               "Call hand_to_flow instead so the flow can answer them." }
    end
end
