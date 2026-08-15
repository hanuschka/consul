require "rails_helper"

describe DeficiencyReport::Watch do
  it "has a valid factory" do
    expect(build(:deficiency_report_watch)).to be_valid
  end

  describe "associations" do
    it "belongs to a deficiency report and a user" do
      expect(DeficiencyReport::Watch.reflect_on_association(:deficiency_report).macro).to eq(:belongs_to)
      expect(DeficiencyReport::Watch.reflect_on_association(:user).macro).to eq(:belongs_to)
    end
  end

  describe "validations" do
    # The bell is a toggle, so a second watch for the same pair would make "watching" ambiguous.
    it "allows only one watch per user and report" do
      watch = create(:deficiency_report_watch)
      duplicate = build(:deficiency_report_watch, deficiency_report: watch.deficiency_report,
                        user: watch.user)

      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:user_id]).to be_present
    end

    it "allows the same user to watch a different report" do
      watch = create(:deficiency_report_watch)
      other = build(:deficiency_report_watch, deficiency_report: create(:deficiency_report),
                    user: watch.user)

      expect(other).to be_valid
    end

    it "allows a different user to watch the same report" do
      watch = create(:deficiency_report_watch)
      other = build(:deficiency_report_watch, deficiency_report: watch.deficiency_report,
                    user: create(:user))

      expect(other).to be_valid
    end
  end

  describe "db constraints" do
    it "has a unique index on the report and user pair" do
      index = ActiveRecord::Base.connection.indexes("deficiency_report_watches").find do |i|
        i.columns.sort == %w[deficiency_report_id user_id]
      end

      expect(index).to be_present
      expect(index.unique).to be(true)
    end
  end

  describe "lifecycle" do
    it "is removed with its deficiency report" do
      watch = create(:deficiency_report_watch)

      expect { watch.deficiency_report.really_destroy! }.to change(DeficiencyReport::Watch, :count).by(-1)
    end
  end
end
