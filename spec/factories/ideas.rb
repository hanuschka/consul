FactoryBot.define do
  factory :idea do
    sequence(:title) { |n| "Idea #{n}" }
    description { "A suggestion for the neighbourhood" }
    resource_terms { "1" }

    association :author, factory: :user

    trait :accepted do
      admin_accepted_at { Time.current }
    end
  end
end
