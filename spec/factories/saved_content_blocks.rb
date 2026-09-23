FactoryBot.define do
  factory :saved_content_block do
    content { "<p>Reusable block</p>" }
    context { "projekt" }

    trait :newsletter do
      context { "newsletter" }
    end
  end
end
