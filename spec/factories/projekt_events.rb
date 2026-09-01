FactoryBot.define do
  factory :projekt_event do
    projekt_phase
    old_projekt { projekt_phase.projekt }
    title { "Stadtlabor zu Besuch" }
    datetime { 1.week.from_now }
  end
end
