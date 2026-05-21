require "rails_helper"

describe RecipientGroupFilter do
  describe "constants" do
    it "exposes the 12 kinds" do
      expect(RecipientGroupFilter::KINDS).to match_array(%w[
        newsletter_subscribers role
        phase_authors phase_subscribers comment_authors voting_participants
        geozone plz age_range gender
        individual_group manual_users
      ])
    end

    it "exposes the 3 operators" do
      expect(RecipientGroupFilter::OPERATORS).to eq(%w[include exclude intersect])
    end
  end

  describe "associations" do
    it "belongs to recipient_group" do
      association = RecipientGroupFilter.reflect_on_association(:recipient_group)
      expect(association).not_to be_nil
      expect(association.macro).to eq(:belongs_to)
    end
  end

  describe "validations" do
    it "validates kind inclusion" do
      filter = RecipientGroupFilter.new(kind: "bogus")
      filter.valid?
      expect(filter.errors[:kind]).to be_present
    end

    it "validates operator inclusion" do
      filter = RecipientGroupFilter.new(operator: "bogus")
      filter.valid?
      expect(filter.errors[:operator]).to be_present
    end
  end
end
