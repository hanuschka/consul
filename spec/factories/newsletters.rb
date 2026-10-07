FactoryBot.define do
  factory :newsletter do
    sequence(:subject) { |n| "Newsletter #{n}" }
    from { "no-reply@example.org" }
    recipient_group
  end
end
