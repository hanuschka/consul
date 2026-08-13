class Ai::Tools::WhatsappAiAssistant::AbortSubmission < Ai::Tools::WhatsappAiAssistant::BaseTool
  description "Cancels the submission or question in progress and tells the citizen so. Call " \
              "it the moment they want to abandon what they are part-way through, however " \
              "they phrase it — \"abbrechen\", \"lass mal\", \"vergiss es\", \"ach doch " \
              "nicht\". Only while something is in progress. Declining one optional part — no " \
              "photo, no location — is not abandoning; that is hand_to_flow with decision " \
              "skip. Asking for no more messages at all is stop_messages, not this. A wrong " \
              "call here throws away everything they wrote, so when in doubt, do not call it. " \
              "This sends the confirmation itself — do not write one as well."

  def execute
    ::Whatsapp::Flows::CancelService.call(conversation: conversation)

    halt("Cancelled the submission in progress.")
  end
end
