class Ai::Tools::WhatsappAiAssistant::StartOver < Ai::Tools::WhatsappAiAssistant::BaseTool
  description "Puts the citizen back at the very beginning, exactly as the \"Von vorne " \
              "loslegen\" button does: the projekt and any vote in progress are left, and a " \
              "contribution they are part-way through is kept until they say to discard it. " \
              "Call it when they want to start over from scratch, however they phrase it — " \
              "\"von vorne\", \"nochmal ganz neu\", \"zurück zum Anfang\". Starting over is " \
              "about the whole conversation, never a restart of the contribution in hand in the " \
              "same projekt: do not call start_draft for it. Only where they plainly mean the " \
              "wording of their draft (\"schreib den Text nochmal neu\") is it revise_draft " \
              "instead. It sends nothing; answer from the hint it returns."

  # Nil while a contribution is kept, which leaves the step where the draft had it.
  def diagnostic_step
    return if conversation.unsaved_submission?

    ::Whatsapp::Conversation::Step::IDLE
  end

  def execute
    ::Whatsapp::AiAssistant::DecisionLog.record(
      event: :start_over,
      conversation: conversation,
      unsaved: conversation.unsaved_submission?,
      typed: true
    )

    conversation.begin_start_over!

    { started_over: true, hint: ::Whatsapp::StartOverNotes.for(conversation) }
  end
end
