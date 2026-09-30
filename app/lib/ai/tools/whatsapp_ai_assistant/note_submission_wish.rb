class Ai::Tools::WhatsappAiAssistant::NoteSubmissionWish < Ai::Tools::WhatsappAiAssistant::BaseTool
  # The typed half of what the "Vorschlag erstellen" tap already records
  # (Whatsapp::Conversation#submission_wished?). Only the tap used to reach it, so
  # a citizen who wrote "Ich möchte eine Idee einreichen" and then picked a projekt
  # was answered with its whole card — every vote and the contributions — and the
  # wish they had just written was nowhere on it. Words are the model's to read,
  # so this is the one place they can be turned into the same fact.
  description "Notes that the citizen wants to submit something — an idea, a proposal, a " \
              "suggestion — before they have said which projekt it is for, so that the card " \
              "of the projekt they pick next offers only the way to submit there rather than " \
              "everything the projekt runs. Call it when they say so in their own words " \
              "(\"Ich möchte eine Idee einreichen\", \"ich hab einen Vorschlag\") and name no " \
              "projekt; tapping \"Vorschlag erstellen\" notes it already. Not needed where they " \
              "name the projekt or the phase themselves — start the submission there. It " \
              "sends nothing: go on with the projekts they can submit to, from " \
              "list_open_projekts."

  def execute
    ::Whatsapp::AiAssistant::DecisionLog.record(
      event: :submission_wish, conversation: conversation, typed: true
    )

    conversation.record_submission_wish!

    {
      noted: true,
      hint: "Offer the projekts open for a submission. The card of the one they pick will " \
            "offer only the way to submit there."
    }
  end
end
