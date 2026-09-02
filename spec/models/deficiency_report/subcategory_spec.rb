require "rails_helper"

describe DeficiencyReport::Subcategory do
  it "has a valid factory" do
    expect(build(:deficiency_report_subcategory)).to be_valid
  end

  describe "validations" do
    it "requires a name" do
      expect(build(:deficiency_report_subcategory, name: "")).not_to be_valid
    end
  end

  describe "associations" do
    it "belongs to a category through the category column" do
      association = DeficiencyReport::Subcategory.reflect_on_association(:category)

      expect(association.macro).to eq(:belongs_to)
      expect(association.options[:class_name]).to eq("DeficiencyReport::Category")
      expect(association.options[:foreign_key]).to eq(:deficiency_report_category_id)
    end

    it "belongs to a polymorphic default responsible" do
      association = DeficiencyReport::Subcategory.reflect_on_association(:default_responsible)

      expect(association.macro).to eq(:belongs_to)
      expect(association.options[:polymorphic]).to be(true)
    end

    it "accepts an officer group as default responsible" do
      group = create(:deficiency_report_officer_group)
      subcategory = create(:deficiency_report_subcategory, default_responsible: group)

      expect(subcategory.reload.default_responsible).to eq(group)
    end

    it "accepts an individual officer as default responsible" do
      officer = create(:deficiency_report_officer)
      subcategory = create(:deficiency_report_subcategory, default_responsible: officer)

      expect(subcategory.reload.default_responsible).to eq(officer)
    end
  end

  describe "db columns" do
    it "carries the order and the AI hint" do
      columns = DeficiencyReport::Subcategory.columns_hash

      expect(columns["given_order"].type).to eq(:integer)
      expect(columns["ai_hint"].type).to eq(:text)
      expect(columns["default_responsible_type"].type).to eq(:string)
    end
  end

  describe "default scope" do
    it "orders by given_order ascending" do
      second = create(:deficiency_report_subcategory, given_order: 2)
      first = create(:deficiency_report_subcategory, given_order: 1)

      expect(DeficiencyReport::Subcategory.all.to_a).to eq([first, second])
    end
  end

  describe ".order_subcategories" do
    it "renumbers given_order from the given id order" do
      first = create(:deficiency_report_subcategory, given_order: 1)
      second = create(:deficiency_report_subcategory, given_order: 2)

      DeficiencyReport::Subcategory.order_subcategories([second.id, first.id])

      expect(second.reload.given_order).to eq(1)
      expect(first.reload.given_order).to eq(2)
    end
  end

  describe "#safe_to_destroy?" do
    let(:subcategory) { create(:deficiency_report_subcategory) }

    it "is true while no report uses the subcategory" do
      expect(subcategory.safe_to_destroy?).to be(true)
    end

    it "is false once a report uses the subcategory" do
      create(:deficiency_report, category: subcategory.category, subcategory: subcategory)

      expect(subcategory.safe_to_destroy?).to be(false)
    end
  end
end
