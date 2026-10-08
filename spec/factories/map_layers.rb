FactoryBot.define do
  factory :map_layer do
    sequence(:name) { |n| "Layer #{n}" }
    provider { "https://wms.example.org/service" }
    protocol { :wms }
    layer_names { "aerial" }
    attribution { "© Example" }
    base { true }
    mappable { nil }

    trait :overlay do
      base { false }
      transparent { true }
    end
  end
end
