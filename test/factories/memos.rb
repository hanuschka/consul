FactoryBot.define do
  factory :memo do
    memoable { nil }
    user { nil }
    text { "MyText" }
  end
end
