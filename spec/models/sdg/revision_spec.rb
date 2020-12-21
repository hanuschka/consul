require "rails_helper"

describe SDG::Revision do
  describe "Validations" do
    it "is valid for any given relatable" do
      revision = build(:sdg_revision, :debate_revision)

      expect(revision).to be_valid
    end

    it "is not valid without a relatable" do
      revision = build(:sdg_revision, relatable: nil)

      expect(revision).not_to be_valid
    end

    it "is not valid when a revision for given relatable already exists" do
      relatable = create(:sdg_revision, :proposal_revision).relatable

      expect(build(:sdg_revision, relatable: relatable)).not_to be_valid
    end
  end
end
