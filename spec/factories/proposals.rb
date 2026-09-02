FactoryBot.define do
  factory :proposal do
    sequence(:title) { |n| "Proposal #{n} title" }
    description      { "Proposal description" }
    responsible_name { "John Snow" }
    resource_terms   { "1" }
    published_at     { Time.current }

    projekt_phase
    association :author, factory: :user
  end
end
