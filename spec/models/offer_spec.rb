require "rails_helper"

describe Offer do
  let(:offer) { build(:offer) }

  it "is valid with a title, a short description, an offer type and a Sozialraum" do
    expect(offer).to be_valid
  end

  it "requires a title" do
    offer.title = ""

    expect(offer).not_to be_valid
  end

  it "treats a short description holding only empty markup as missing" do
    offer.short_description = "<p>&nbsp;</p>"

    expect(offer).not_to be_valid
    expect(offer.errors[:short_description]).to be_present
  end

  it "requires at least one offer type and at least one Sozialraum" do
    offer = Offer.new(title: "Schwimmkurs", short_description: "<p>Text</p>")

    expect(offer).not_to be_valid
    expect(offer.errors[:base]).to contain_exactly(
      I18n.t("activerecord.errors.models.offer.category_required",
             category: I18n.t("activerecord.attributes.offer/category.kinds.offer_type")),
      I18n.t("activerecord.errors.models.offer.category_required",
             category: I18n.t("activerecord.attributes.offer/category.kinds.social_area"))
    )
  end

  it "does not require a location, target group, costs or accessibility" do
    expect(offer.map_location).to be_nil
    expect(offer.categories_of(:target_group)).to be_empty
    expect(offer).to be_valid
  end

  it "carries several values per category" do
    north, south = create_list(:offer_category, 2, :social_area)
    groups = create_list(:offer_category, 3, :target_group)
    offer = create(:offer, categories: [create(:offer_category, :offer_type), north, south, *groups])

    expect(offer.reload.categories_of(:social_area)).to match_array [north, south]
    expect(offer.categories_of(:target_group)).to match_array groups
  end

  it "accepts only http and https websites" do
    offer.contact_website = "javascript:alert(1)"
    expect(offer).not_to be_valid

    offer.contact_website = "https://www.jena.de"
    expect(offer).to be_valid
  end

  it "validates the contact e-mail format" do
    offer.contact_email = "not-an-address"

    expect(offer).not_to be_valid
  end
end

describe Offer::Category do
  it "only accepts the known kinds" do
    expect(build(:offer_category, kind: "colour")).not_to be_valid
  end

  it "cannot be deleted while an offer uses it" do
    category = create(:offer_category, :social_area)
    create(:offer, categories: [create(:offer_category, :offer_type), category])

    expect(category.destroy).to be false
    expect(category.errors[:base]).to be_present
    expect(Offer::Category.exists?(category.id)).to be true
  end

  it "can be deleted when unused" do
    category = create(:offer_category)

    expect { category.destroy }.to change(Offer::Category, :count).by(-1)
  end
end
