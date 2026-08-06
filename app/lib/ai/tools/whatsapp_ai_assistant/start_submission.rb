class Ai::Tools::WhatsappAiAssistant::StartSubmission < Ai::Tools::WhatsappAiAssistant::BaseTool
  description "Starts submitting an idea when the citizen has not said which projekt: it opens " \
              "the only phase if just one is running, and otherwise asks them to pick. Use it " \
              "for I want to submit something, I have an idea, how do I propose this. When they " \
              "did name a phase, call start_phase_flow instead. This sends the message itself: " \
              "do not write one as well. You take no further part in the submission after this."

  # Abandons whatever was open first, for the same reason the menu does: asking
  # to submit something is a fresh start, not a continuation of a flow the
  # citizen has stopped answering.
  def execute
    conversation.reset_flow!

    ::Whatsapp::NextStepService.call(conversation: conversation)

    halt("Started the submission flow.")
  end
end
