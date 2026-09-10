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

    trait :voting_phase do
      type { "ProjektPhase::VotingPhase" }
    end
  end

  factory :mitmachbox_phase, parent: :projekt_phase, class: "ProjektPhase::MitmachboxPhase" do
    type { "ProjektPhase::MitmachboxPhase" }
    mitmachbox_survey_id { 7 }
  end
end
