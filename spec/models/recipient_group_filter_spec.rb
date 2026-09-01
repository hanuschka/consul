require "rails_helper"

describe RecipientGroupFilter do
  let(:group) { create(:recipient_group) }

  it "has a valid factory" do
    expect(build(:recipient_group_filter)).to be_valid
  end

  describe "constants" do
    it "exposes the 13 kinds" do
      expect(RecipientGroupFilter::KINDS).to match_array(%w[
        newsletter_subscribers role
        phase_authors phase_subscribers projekt_subscribers comment_authors voting_participants
        district plz age_range gender
        individual_group manual_users
      ])
    end

    it "exposes the 3 operators" do
      expect(RecipientGroupFilter::OPERATORS).to eq(%w[include exclude intersect])
    end

    # REQUIRED_PARAMS is documentation only — nothing validates against it —
    # so this guards it from drifting away from the kinds it describes.
    it "documents required params for every kind" do
      expect(RecipientGroupFilter::REQUIRED_PARAMS.keys).to match_array(RecipientGroupFilter::KINDS)
    end
  end

  describe "validations" do
    it { should validate_inclusion_of(:kind).in_array(RecipientGroupFilter::KINDS) }
    it { should validate_inclusion_of(:operator).in_array(RecipientGroupFilter::OPERATORS) }
  end

  describe "associations" do
    it { should belong_to(:recipient_group) }
  end

  describe "db columns" do
    it { should have_db_column(:recipient_group_id).of_type(:integer) }
    it { should have_db_column(:position).of_type(:integer) }
    it { should have_db_column(:kind).of_type(:string) }
    it { should have_db_column(:operator).of_type(:string) }
    it { should have_db_column(:params).of_type(:jsonb) }
    it { should have_db_index(:kind) }
    it { should have_db_index(:recipient_group_id) }
  end

  describe "positioning" do
    it "numbers filters in creation order" do
      first = create(:recipient_group_filter, recipient_group: group)
      second = create(:recipient_group_filter, recipient_group: group, operator: "intersect")

      expect([first.position, second.position]).to eq([1, 2])
    end

    it "counts positions per recipient group" do
      create(:recipient_group_filter, recipient_group: group)
      other = create(:recipient_group_filter, recipient_group: create(:recipient_group))

      expect(other.position).to eq(1)
    end
  end

  describe "first_filter_must_be_include validation" do
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
      second = group.filters.new(kind: "newsletter_subscribers", operator: "intersect", params: {})

      expect(second.save).to be(true)
      expect(second.position).to eq(2)
    end

    it "ignores the filter itself when re-validating a persisted first filter" do
      filter = create(:recipient_group_filter, recipient_group: group)
      filter.operator = "exclude"

      expect(filter).not_to be_valid
    end
  end

  describe "params validation per kind" do
    # The UI mutates `kind` and `params` in separate Turbo PATCHes, so a freshly
    # switched filter often has the new kind without any params yet. Blocking
    # the save would corrupt the persisted state (kind reverts to whatever was
    # last valid) and break the multi-step edit flow.
    it "accepts district filter without district_ids (partial UI state)" do
      filter = build(:recipient_group_filter, recipient_group: group, kind: "district", params: {})

      expect(filter).to be_valid
    end

    it "accepts district filter with district_ids" do
      filter = build(:recipient_group_filter, recipient_group: group, kind: "district",
                     params: { "district_ids" => [1] })

      expect(filter).to be_valid
    end

    it "accepts phase_authors without projekt_phase_id (partial UI state)" do
      filter = build(:recipient_group_filter, recipient_group: group, kind: "phase_authors",
                     params: { "criterion" => "winners" })

      expect(filter).to be_valid
    end

    context "with kind role" do
      it "rejects an unsupported role" do
        filter = build(:recipient_group_filter, recipient_group: group, kind: "role",
                       params: { "role" => "nope" })

        expect(filter).not_to be_valid
        expect(filter.errors[:params]).to be_present
      end

      it "accepts a blank role (partial UI state)" do
        filter = build(:recipient_group_filter, recipient_group: group, kind: "role", params: {})

        expect(filter).to be_valid
      end

      it "accepts every role the params form offers" do
        filters = RecipientGroupFilter::ALLOWED_ROLES.map do |role|
          build(:recipient_group_filter, recipient_group: group, kind: "role", params: { "role" => role })
        end

        expect(filters).to all(be_valid)
      end
    end
  end
end
