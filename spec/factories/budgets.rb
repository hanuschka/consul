FactoryBot.define do
  factory :budget do
    sequence(:name) { |n| "Budget #{n}" }
    sequence(:slug) { |n| "budget-#{n}" }
    currency_symbol { "€" }
    phase { "accepting" }
    voting_style { "knapsack" }

    projekt_phase do
      create(:projekt_phase, :budget_phase,
             active: true, start_date: 1.day.ago, end_date: 1.day.from_now)
    end

    trait :with_heading do
      after(:create) do |budget|
        create(:budget_heading, group: create(:budget_group, budget: budget))
        budget.reload
      end
    end

    trait :accepting_now do
      after(:create) do |budget|
        budget.phases.where.not(kind: "accepting").update_all(enabled: false)
        budget.reload
      end
    end
  end

  factory :budget_group, class: "Budget::Group" do
    budget
    sequence(:name) { |n| "Group #{n}" }
    sequence(:slug) { |n| "group-#{n}" }
  end

  factory :budget_heading, class: "Budget::Heading" do
    association :group, factory: :budget_group
    sequence(:name) { |n| "Heading #{n}" }
    sequence(:slug) { |n| "heading-#{n}" }
    price { 1_000_000 }
    max_ballot_lines { 1 }
  end
end
