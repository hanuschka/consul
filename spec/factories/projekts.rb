FactoryBot.define do
  factory :projekt do
    sequence(:name) { |n| "Projekt #{n}" }

    total_duration_start { 1.month.ago }
    total_duration_end { 1.month.from_now }
  end
end
