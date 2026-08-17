require "rails_helper"

describe DeficiencyReport::Category do
  it "has a valid factory" do
    expect(build(:deficiency_report_category)).to be_valid
  end

  describe "associations" do
    it "has many subcategories, destroyed with the category" do
      association = DeficiencyReport::Category.reflect_on_association(:subcategories)

      expect(association.macro).to eq(:has_many)
      expect(association.options[:class_name]).to eq("DeficiencyReport::Subcategory")
      expect(association.options[:dependent]).to eq(:destroy)
    end

    it "takes its subcategories down with it" do
      category = create(:deficiency_report_category)
      create(:deficiency_report_subcategory, category: category)

      expect { category.destroy }.to change(DeficiencyReport::Subcategory, :count).by(-1)
    end

    it "belongs to a polymorphic default responsible" do
      association = DeficiencyReport::Category.reflect_on_association(:default_responsible)

      expect(association.macro).to eq(:belongs_to)
      expect(association.options[:polymorphic]).to be(true)
    end
  end

  describe "db columns" do
    it "carries the AI fallback flag and the AI hint" do
      columns = DeficiencyReport::Category.columns_hash

      expect(columns["ai_fallback"].type).to eq(:boolean)
      expect(columns["ai_hint"].type).to eq(:text)
    end
  end

  describe ".ai_fallback" do
    it "returns the category flagged as fallback" do
      create(:deficiency_report_category, given_order: 1)
      flagged = create(:deficiency_report_category, given_order: 2, ai_fallback: true)

      expect(DeficiencyReport::Category.ai_fallback).to eq(flagged)
    end

    # The AI feature needs somewhere to put an unclassifiable report before anybody marks a
    # fallback, so this falls back to the first category rather than returning nothing.
    it "falls back to the first category when none is flagged" do
      first = create(:deficiency_report_category, given_order: 1)
      create(:deficiency_report_category, given_order: 2)

      expect(DeficiencyReport::Category.ai_fallback).to eq(first)
    end

    it "returns nil when there are no categories at all" do
      expect(DeficiencyReport::Category.ai_fallback).to be_nil
    end
  end

  describe "single ai_fallback enforcement" do
    it "unsets the previous fallback when another one is flagged" do
      old_fallback = create(:deficiency_report_category, ai_fallback: true)
      new_fallback = create(:deficiency_report_category, ai_fallback: true)

      expect(old_fallback.reload.ai_fallback).to be(false)
      expect(new_fallback.reload.ai_fallback).to be(true)
    end

    it "leaves the flagged category alone when a non-fallback one is saved" do
      flagged = create(:deficiency_report_category, ai_fallback: true)
      create(:deficiency_report_category, ai_fallback: false)

      expect(flagged.reload.ai_fallback).to be(true)
    end
  end

  describe "#safe_to_destroy?" do
    let(:category) { create(:deficiency_report_category) }

    it "is true while no report uses the category" do
      expect(category.safe_to_destroy?).to be(true)
    end

    it "is false once a report uses the category" do
      create(:deficiency_report, category: category)

      expect(category.safe_to_destroy?).to be(false)
    end
  end
end
