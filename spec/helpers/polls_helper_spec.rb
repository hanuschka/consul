require "rails_helper"

describe PollsHelper do
  describe "#cannot_answer_callout_text" do
    let(:voting_phase) { create(:projekt).projekt_phases.create!(type: "ProjektPhase::VotingPhase") }

    before { set_setting("extended_feature.general.sms_login", true) }

    it "offers SMS sign-in when the visitor is signed out" do
      text = helper.cannot_answer_callout_text(:not_logged_in, voting_phase)

      expect(text).to include(I18n.t("sms_sign_in.hint.link"))
    end

    it "offers SMS sign-in on guest phases" do
      text = helper.cannot_answer_callout_text(:guest_not_logged_in, voting_phase)

      expect(text).to include(I18n.t("sms_sign_in.hint.link"))
    end

    it "does not offer SMS sign-in for other problems" do
      text = helper.cannot_answer_callout_text(:not_verified, voting_phase)

      expect(text).not_to include(I18n.t("sms_sign_in.hint.link"))
    end
  end
end
