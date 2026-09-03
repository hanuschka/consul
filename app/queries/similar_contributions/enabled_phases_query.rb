class SimilarContributions::EnabledPhasesQuery < ApplicationQuery
  def call
    ProjektPhase
      .where(type: ["ProjektPhase::ProposalPhase", "ProjektPhase::BudgetPhase"])
      .where(id: enabled_phase_ids)
  end

  private

    def enabled_phase_ids
      ProjektPhaseSetting
        .where(key: "feature.#{SimilarContributions::Scopes::SETTING_KEY}")
        .where.not(value: [nil, ""])
        .select(:projekt_phase_id)
    end
end
