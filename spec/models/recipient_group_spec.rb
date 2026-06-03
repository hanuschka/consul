require "rails_helper"

describe RecipientGroup do
  describe "associations" do
    it "has many filters" do
      association = RecipientGroup.reflect_on_association(:filters)
      expect(association).not_to be_nil
      expect(association.macro).to eq(:has_many)
      expect(association.options[:class_name]).to eq("RecipientGroupFilter")
      expect(association.options[:dependent]).to eq(:destroy)
    end

    it "has many newsletters" do
      association = RecipientGroup.reflect_on_association(:newsletters)
      expect(association).not_to be_nil
      expect(association.macro).to eq(:has_many)
      expect(association.options[:dependent]).to eq(:restrict_with_exception)
    end
  end

  describe "validations" do
    it "validates presence of name" do
      group = RecipientGroup.new(name: "")
      group.valid?
      expect(group.errors[:name]).to be_present
    end
  end

  describe "#filters ordering" do
    it "returns filters ordered by position" do
      group = create(:recipient_group)
      f2 = create(:recipient_group_filter, recipient_group: group, position: 2)
      f1 = create(:recipient_group_filter, recipient_group: group, position: 1)
      expect(group.filters.to_a).to eq([f1, f2])
    end
  end
end
