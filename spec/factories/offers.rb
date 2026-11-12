FactoryBot.define do
  factory :offer_category, class: "Offer::Category" do
    kind { "offer_type" }
    sequence(:name) { |n| "Kategorie #{n}" }

    Offer::Category::KINDS.each do |category_kind|
      trait category_kind.to_sym do
        kind { category_kind }
      end
    end
  end

  factory :offer do
    sequence(:title) { |n| "Angebot #{n}" }
    short_description { "<p>Kurzbeschreibung</p>" }

    after(:build) do |offer|
      Offer::REQUIRED_CATEGORY_KINDS.each do |kind|
        next if offer.category_assignments.any? { |assignment| assignment.category&.kind == kind }

        offer.category_assignments.build(category: create(:offer_category, kind: kind))
      end
    end
  end
end
