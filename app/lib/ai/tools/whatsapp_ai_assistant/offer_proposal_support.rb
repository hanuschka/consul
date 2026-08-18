class Ai::Tools::WhatsappAiAssistant::OfferProposalSupport <
  Ai::Tools::WhatsappAiAssistant::BaseTool
  description "Finds the proposal a citizen wants to support from what they called it, and asks " \
              "them to confirm before anything is registered. Call this when they say they want " \
              "to support, back or sign a proposal and name it, however roughly. Returns the " \
              "candidates when more than one matches, so you can ask which they mean; call it " \
              "again with the clearer wording. Do not call support_proposal until this " \
              "conversation is about one specific proposal."

  params do
    string :title, description: "What the citizen called the proposal, in their own words"
  end

  def execute(title:)
    matches = ::Whatsapp::SupportableProposalsQuery.call(text: title)

    return no_proposal_match_error(title) if matches.empty?

    if matches.size > 1
      return { candidates: matches.map { |proposal| proposal_candidate_summary(proposal) }}
    end

    ::Whatsapp::Flows::SupportService.prompt(conversation: conversation, proposal: matches.first)

    halt("Asked the citizen to confirm supporting this proposal.")
  end
end
