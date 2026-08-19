class Ai::Tools::WhatsappAiAssistant::SetDraftSentiment < Ai::Tools::WhatsappAiAssistant::BaseTool
  description "Records which sentiment the citizen chose for their draft — whether it reads as " \
              "praise, a criticism, a suggestion, or whatever this phase offers. Only the ids " \
              "this phase offers are accepted, and draft_status returns them. Ask them in your " \
              "own words first; this only records the answer and sends nothing. A draft that was " \
              "waiting on this choice is saved by it."

  params do
    integer :option_id,
      description: "Id of the chosen sentiment, from the options this phase offers"
  end

  def diagnostic_step
    ::Whatsapp::Conversation::Step::AWAITING_SENTIMENT
  end

  def execute(option_id:)
    outcome = ::Whatsapp::Drafting::AssignDraftChoiceService.call(
      conversation: conversation,
      policy: ::Whatsapp::DraftTaxonomy.sentiment(projekt_phase),
      option_id: option_id
    )

    draft_choice_answer(outcome, "sentiment")
  end
end
