FactoryBot.define do
  factory :individual_group_value do
    individual_group
    sequence(:name) { |n| "Individual group value #{n}" }
  end
end
