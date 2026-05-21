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

    trait :debate_phase do
      type { "ProjektPhase::DebatePhase" }
    end
  end
end
