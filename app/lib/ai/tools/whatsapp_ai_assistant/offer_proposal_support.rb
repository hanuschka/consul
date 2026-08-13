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

    return no_match_error(title) if matches.empty?
    return { candidates: matches.map { |proposal| summary_of(proposal) }} if matches.size > 1

    ::Whatsapp::Flows::SupportService.prompt(conversation: conversation, proposal: matches.first)

    halt("Asked the citizen to confirm supporting this proposal.")
  end

  private

    def summary_of(proposal)
      projekt = proposal.projekt_phase&.projekt

      {
        proposal_id: proposal.id,
        title: proposal.title,
        projekt: projekt.present? ? projekt_title(projekt) : nil,
        supports: proposal.cached_votes_up
      }.compact
    end

    def no_match_error(title)
      {
        error: "No publicly listed proposal matches \"#{title}\". Tell the citizen you could not " \
               "find it and ask for the title as it appears on the projekt page."
      }
    end
end
