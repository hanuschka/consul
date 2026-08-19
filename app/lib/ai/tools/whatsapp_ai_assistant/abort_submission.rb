class Ai::Tools::WhatsappAiAssistant::AbortSubmission < Ai::Tools::WhatsappAiAssistant::BaseTool
  description "Throws away the draft in progress. Call it the moment the citizen wants to " \
              "abandon what they are part-way through, however they phrase it — \"abbrechen\", " \
              "\"lass mal\", \"vergiss es\", \"ach doch nicht\". Declining one optional part is " \
              "not abandoning: no photo and no pin are answers to be gone on from, not reasons " \
              "to discard. Asking for no more messages at all is stop_messages. A wrong call " \
              "here throws away everything they wrote and it cannot be recovered, so when in " \
              "doubt ask them first. Say afterwards, in one line, that it is discarded."

  def diagnostic_step
    ::Whatsapp::Conversation::Step::IDLE
  end

  def execute
    return nothing_open_answer if !conversation.unsaved_submission?

    conversation.discard_draft!

    {
      discarded: true,
      hint: "Say in one line that it is gone and that they can start again whenever they like. " \
            "Do not list what else the portal offers unless they ask."
    }
  end

  private

    def nothing_open_answer
      {
        discarded: false,
        hint: "There was nothing in progress to discard, so do not tell them anything was. " \
              "Answer what they actually asked."
      }
    end
end
