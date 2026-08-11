FactoryBot.define do
  factory :projekt_phase do
    projekt
    type { "ProjektPhase::ProposalPhase" }

    trait :proposal_phase do
      type { "ProjektPhase::ProposalPhase" }
    end

    trait :budget_phase do
      type { "ProjektPhase::BudgetPhase" }
    end
  end
end
