FactoryBot.define do
  factory :site_customization_content_card, class: 'SiteCustomization::ContentCard' do
    order { 1 }
    active { false }
    settings { "" }
    kind { "MyString" }
  end
end
