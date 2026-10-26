require "rails_helper"

describe User do
  let(:user) { create(:user) }
  let!(:idea) { create(:idea, author: user) }
  let!(:report) { create(:deficiency_report, author: user) }
  let!(:other_idea) { create(:idea) }
  let!(:other_report) { create(:deficiency_report) }

  describe "#block" do
    it "hides the user's ideas and deficiency reports" do
      user.block

      expect(Idea.all).to eq([other_idea])
      expect(DeficiencyReport.all).to eq([other_report])
    end
  end

  describe "#full_restore" do
    it "brings back the ideas and deficiency reports the block hid" do
      user.block
      user.full_restore

      expect(Idea.all).to match_array([idea, other_idea])
      expect(DeficiencyReport.all).to match_array([report, other_report])
    end

    it "keeps ideas and deficiency reports hidden that were hidden before the block" do
      moderated_idea = create(:idea, author: user)
      moderated_report = create(:deficiency_report, author: user)
      travel_to(1.day.ago) do
        moderated_idea.hide
        moderated_report.hide
      end

      user.block
      user.full_restore

      expect(Idea.all).not_to include(moderated_idea)
      expect(DeficiencyReport.all).not_to include(moderated_report)
    end
  end
end
