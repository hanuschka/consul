class Ai::Tools::WhatsappAiAssistant::SetDraftCategory < Ai::Tools::WhatsappAiAssistant::BaseTool
  description "Records which category the citizen chose for their draft. Only the ids this " \
              "phase actually offers are accepted — draft_status and draft_proposal both return " \
              "them — so never invent one or carry one over from another projekt. Ask them in " \
              "your own words first, offering the options as buttons or a list; this only " \
              "records the answer and sends nothing. A draft that was waiting on this choice is " \
              "saved by it, so what comes back says whether anything else is still needed."

  params do
    integer :option_id, description: "Id of the chosen category, from the options this phase offers"
  end

  def diagnostic_step
    ::Whatsapp::Conversation::Step::AWAITING_CATEGORY
  end

  def execute(option_id:)
    outcome = ::Whatsapp::Drafting::AssignDraftChoiceService.call(
      conversation: conversation,
      policy: ::Whatsapp::DraftTaxonomy.category(projekt_phase),
      option_id: option_id
    )

    draft_choice_answer(outcome, "category")
  end
end
