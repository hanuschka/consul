class Ai::Tools::WhatsappAiAssistant::CheckParticipationEligibility <
  Ai::Tools::WhatsappAiAssistant::BaseTool

  description "Checks whether this citizen may submit something to an open participation phase " \
              "right now, and why not when they may not — for example because their account is " \
              "not verified or the phase does not accept submissions. Call this before telling " \
              "the citizen they can contribute, and before start_phase_flow when in doubt."

  params do
    integer :projekt_phase_id, description: "Id of an open participation phase"
  end

  def execute(projekt_phase_id:)
    projekt_phase = eligible_phase(projekt_phase_id)

    return unknown_phase_error if projekt_phase.blank?

    permission_problem =
      ::Whatsapp::Drafting::ResourceCreationValidationService.call(projekt_phase: projekt_phase, user: user)

    return { eligible: true } if permission_problem.blank?

    {
      eligible: false,
      reason: permission_problem.to_s,
      explanation: explanation_for(permission_problem)
    }
  end

  private

    # The same copy the deterministic refusal sends, so the two paths never
    # give the citizen two different accounts of the same rule.
    def explanation_for(reason)
      reason_key = ::Whatsapp::Flows::RefuseParticipationService.reason_key(reason)

      I18n.t("whatsapp.bot.refused.#{reason_key}")
    end
end
