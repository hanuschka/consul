FactoryBot.define do
  factory :recipient_group do
    sequence(:name) { |n| "Recipient Group #{n}" }
  end

  factory :recipient_group_filter do
    recipient_group
    kind { "newsletter_subscribers" }
    operator { "include" }
    params { {} }
  end
end
