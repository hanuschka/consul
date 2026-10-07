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

  factory :proposal_phase, parent: :projekt_phase, class: "ProjektPhase::ProposalPhase" do
    type { "ProjektPhase::ProposalPhase" }
  end

  factory :budget_phase, parent: :projekt_phase, class: "ProjektPhase::BudgetPhase" do
    type { "ProjektPhase::BudgetPhase" }
  end

  factory :point_of_interest_phase, parent: :projekt_phase, class: "ProjektPhase::PointOfInterestPhase" do
    type { "ProjektPhase::PointOfInterestPhase" }
  end

  factory :mitmachbox_phase, parent: :projekt_phase, class: "ProjektPhase::MitmachboxPhase" do
    type { "ProjektPhase::MitmachboxPhase" }
    mitmachbox_survey_id { 7 }
  end
end
