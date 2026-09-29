class Ai::Tools::WhatsappAiAssistant::CheckParticipationEligibility <
  Ai::Tools::WhatsappAiAssistant::BaseTool
  description "Checks whether this citizen may submit something to an open participation phase " \
              "right now, and which rule stops them when they may not — an unverified account, a " \
              "phase that has closed, a district or age limit, a submission allowance already " \
              "spent. Call it before telling them they can contribute. It returns the rule for " \
              "you to explain in your own words and sends nothing itself; where it names a way " \
              "forward, offer that rather than leaving them at a refusal."

  params do
    integer :projekt_phase_id, description: "Id of an open participation phase"
  end

  def execute(projekt_phase_id:)
    candidate = eligible_phase(projekt_phase_id)

    return unknown_phase_error if candidate.blank?

    problem = ::Whatsapp::Drafting::ResourceCreationValidationService.call(
      projekt_phase: candidate, user: user
    )

    return { eligible: true } if problem.blank?

    {
      eligible: false,
      reason: problem.to_s,
      # The rule rather than the sentence. Both paths that refuse a citizen read
      # this one explanation, so the answer to "may I take part" and the answer to
      # an attempt that was stopped cannot give two different accounts of the same
      # rule.
      rule: ::Whatsapp::ParticipationRules.explain(reason: problem, projekt_phase: candidate)
    }
  end
end
