require "rails_helper"

describe ModerationMailer do
  describe "#flag_report" do
    it "links the review to the flagged proposals in /adm" do
      Setting["moderation.reports_notification_email"] = "moderation@beispiel.de"
      flag = Flag.create!(user: create(:user), flaggable: create(:proposal))

      body = described_class.flag_report(flag).body.decoded

      expect(body).to include "/adm/moderation/proposals"
      expect(body).not_to include "/moderation/proposals?filter=unseen"
    end
  end
end
