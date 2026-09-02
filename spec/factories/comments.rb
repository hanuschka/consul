FactoryBot.define do
  factory :comment do
    association :commentable, factory: :projekt_phase
    user
    sequence(:body) { |n| "Comment body #{n}" }
  end
end
