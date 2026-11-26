require "rails_helper"

describe ProjektPhase::VotingPhase, "participation" do
  let(:citizen) { create(:user) }
  let(:phase) { create(:voting_phase, active: true, user_status: "registered") }
  let(:poll) { phase.poll }

  describe "default settings of a new voting phase" do
    it "uses wizard mode and shows the poll on the home and index pages" do
      expect(phase.feature?("resource.wizard_mode")).to be true
      expect(phase.feature?("resource.show_on_home_page")).to be true
      expect(phase.feature?("resource.show_on_index_page")).to be true
    end

    it "shows intermediate results to moderators" do
      expect(phase.feature?("resource.intermediate_poll_results_for_admins")).to be true
    end

    it "keeps comments, open answer author names and the report for citizens switched off" do
      expect(phase.feature?("resource.show_comments")).to be false
      expect(phase.feature?("resource.show_open_answer_author_name")).to be false
      expect(phase.feature?("resource.report_visible_for_citizens")).to be false
    end

    it "creates its poll switched off" do
      expect(poll).to be_present
      expect(poll.live).to be false
    end
  end

  describe "when a citizen may answer" do
    it "not while the poll is not live" do
      expect(phase.permission_problem(citizen)).to eq(:poll_not_live)
      expect(poll.answerable_by?(citizen)).to be false
    end

    it "once the poll is live" do
      poll.update!(live: true)

      expect(ProjektPhase.find(phase.id).permission_problem(citizen)).to be_nil
    end

    it "not once the phase has ended, even with a live poll" do
      poll.update!(live: true)
      phase.update!(end_date: 1.day.ago)

      expect(ProjektPhase.find(phase.id).permission_problem(citizen)).to eq(:phase_expired)
    end

    it "at the in-person booth even while the poll is not live" do
      expect(phase.permission_problem(citizen, location: :officing)).to be_nil
    end
  end

  describe "comments on a poll" do
    it "are allowed exactly for those who may answer" do
      poll.update!(live: true)
      live_poll = Poll.find(poll.id)

      expect(live_poll.comments_allowed?(citizen)).to eq(live_poll.answerable_by?(citizen))
      expect(live_poll.comments_allowed?(citizen)).to be true
    end
  end
end
