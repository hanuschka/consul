FactoryBot.define do
  factory :user do
    sequence(:username)   { |n| "Manuela#{n}" }
    sequence(:email)      { |n| "manuela#{n}@consul.dev" }

    password              { "Aa12345678!" }
    terms_data_storage    { "1" }
    terms_data_protection { "1" }
    terms_general         { "1" }
    confirmed_at          { Time.current }

    trait :verified do
      verified_at { Time.current }
    end

    trait :unconfirmed do
      confirmed_at { nil }

      after(:build, &:skip_confirmation_notification!)
    end
  end

  factory :administrator do
    user
  end

  factory :moderator do
    user
  end
end
