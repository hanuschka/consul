FactoryBot.define do
  factory :site_customization_content_block, class: "SiteCustomization::ContentBlock" do
    name { "custom" }
    locale { I18n.default_locale }
    sequence(:key) { |n| "content_block_#{n}" }
    body { "<p>Text</p>" }

    trait :newsletter do
      newsletter
    end
  end
end
