require "rails_helper"

describe RecipientGroupFilter do
  describe "constants" do
    it "exposes the 13 kinds" do
      expect(RecipientGroupFilter::KINDS).to match_array(%w[
        newsletter_subscribers role
        phase_authors phase_subscribers projekt_subscribers comment_authors voting_participants
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

  describe "first_filter_must_be_include validation" do
    let(:group) { create(:recipient_group) }

    it "rejects exclude as the first filter" do
      filter = build(:recipient_group_filter, recipient_group: group, operator: "exclude")
      expect(filter).not_to be_valid
      expect(filter.errors[:operator]).to be_present
    end

    it "rejects intersect as the first filter" do
      filter = build(:recipient_group_filter, recipient_group: group, operator: "intersect")
      expect(filter).not_to be_valid
    end

    it "allows include as the first filter" do
      filter = build(:recipient_group_filter, recipient_group: group, operator: "include")
      expect(filter).to be_valid
    end

    it "allows exclude as the second filter" do
      create(:recipient_group_filter, recipient_group: group, position: 1)
      second = build(:recipient_group_filter, recipient_group: group, operator: "exclude", position: 2)
      expect(second).to be_valid
    end

    # Regression: position is set by acts_as_list in before_create (after
    # validation). When the second filter is built without an explicit
    # position, it would previously fall back to position.to_i == 0,
    # making the existing filter look like it came after — and falsely
    # triggering the "first filter must be include" error.
    it "allows intersect as the second filter even when position is not preset" do
      create(:recipient_group_filter, recipient_group: group, position: 1)
      second = build(:recipient_group_filter, recipient_group: group, operator: "intersect")
      expect(second).to be_valid
    end

    it "allows exclude as the second filter even when position is not preset" do
      create(:recipient_group_filter, recipient_group: group, position: 1)
      second = build(:recipient_group_filter, recipient_group: group, operator: "exclude")
      expect(second).to be_valid
    end

    it "persists a second filter with intersect via create" do
      create(:recipient_group_filter, recipient_group: group, position: 1)
      second = group.filters.create(kind: "newsletter_subscribers", operator: "intersect", params: {})
      expect(second).to be_persisted
      expect(second.position).to eq(2)
    end
  end

  describe "params validation per kind" do
    let(:group) { create(:recipient_group) }

    # The UI mutates `kind` and `params` in separate Turbo PATCHes, so a freshly
    # switched filter often has the new kind without any params yet. Blocking
    # the save would corrupt the persisted state (kind reverts to whatever was
    # last valid) and break the multi-step edit flow.
    it "accepts geozone filter without geozone_ids (partial UI state)" do
      f = build(:recipient_group_filter, recipient_group: group, kind: "geozone", params: {})
      expect(f).to be_valid
    end

    it "accepts geozone filter with geozone_ids" do
      f = build(:recipient_group_filter, recipient_group: group, kind: "geozone", params: { "geozone_ids" => [1] })
      expect(f).to be_valid
    end

    it "rejects role filter with unsupported role" do
      f = build(:recipient_group_filter, recipient_group: group, kind: "role", params: { "role" => "nope" })
      expect(f).not_to be_valid
    end

    it "accepts role filter with allowed role" do
      f = build(:recipient_group_filter, recipient_group: group, kind: "role", params: { "role" => "administrator" })
      expect(f).to be_valid
    end

    it "accepts role filter with blank role (partial UI state)" do
      f = build(:recipient_group_filter, recipient_group: group, kind: "role", params: {})
      expect(f).to be_valid
    end

    it "accepts phase_authors without projekt_phase_id (partial UI state)" do
      f = build(:recipient_group_filter, recipient_group: group, kind: "phase_authors", params: { "criterion" => "winners" })
      expect(f).to be_valid
    end
  end
end
