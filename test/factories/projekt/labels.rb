FactoryBot.define do
  factory :projekt_label, class: 'Projekt::Label' do
    color { "MyString" }
    icon { "MyString" }
    projekt { nil }
  end
end
