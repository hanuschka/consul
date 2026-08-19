class Ai::Tools::WhatsappAiAssistant::SupportProposal < Ai::Tools::WhatsappAiAssistant::BaseTool
  description "Registers the citizen's support for one proposal and returns the new count. " \
              "Support cannot be withdrawn, so call it only once they have clearly said yes to " \
              "that one proposal — show them its title and link first and let them agree. Pass " \
              "the id find_contribution returned; never guess one. The proposal is re-checked " \
              "here, so a phase that has since closed or a proposal that has been retired " \
              "refuses rather than acting."

  params do
    integer :contribution_id,
      description: "Id of the proposal, exactly as find_contribution returned it"
  end

  def execute(contribution_id:)
    return not_linked_error("support a proposal") if user.blank?

    outcome = ::Whatsapp::Contributions::RegisterSupportService.call(
      proposal_id: contribution_id, user: user
    )

    return refusal_for(outcome) if outcome.is_a?(Symbol)

    {
      supported: true,
      supports: outcome,
      hint: "Tell them it is registered and how many supports the proposal now has. Do not " \
            "invite them to support anything else."
    }
  end

  private

    def refusal_for(outcome)
      return gone_error if outcome == :gone
      return already_supported_answer if outcome == :already_supported
      return not_linked_error("support a proposal") if outcome == :not_linked

      {
        error: "This citizen may not support that proposal.",
        reason: outcome.to_s,
        rule: ::Whatsapp::ParticipationRules.explain(reason: outcome)
      }
    end

    def gone_error
      { error: "That proposal no longer has a public page — it may have been retired since it " \
               "was mentioned. Tell the citizen so; nothing was registered." }
    end

    def already_supported_answer
      {
        supported: false,
        already: true,
        hint: "They had already supported it. Say so plainly rather than as a failure."
      }
    end
end
