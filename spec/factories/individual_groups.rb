FactoryBot.define do
  factory :individual_group do
    sequence(:name) { |n| "Individual group #{n}" }
  end
end
