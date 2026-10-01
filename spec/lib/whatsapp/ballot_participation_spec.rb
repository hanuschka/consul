require "rails_helper"

describe Whatsapp::BallotParticipation do
  let(:user) { create(:user) }
  let(:poll) { create(:poll) }
  let!(:choice_question) { create(:poll_question, poll: poll, title: "Lieblingsfarbe") }
  let!(:option) { create(:poll_question_answer, question: choice_question, title: "Blau") }
  let!(:map_question) { create(:poll_question, :map_points, poll: poll, title: "Kartenpunkt") }

  describe ".states_by_poll_id" do
    it "leaves a ballot with nothing recorded out, which counts it as not answered" do
      expect(described_class.states_by_poll_id(polls: [poll], user: user)).to eq({})
    end

    it "reads a ballot with a question skipped as partly answered, not answered in full" do
      choice_question.find_or_initialize_user_answer(user, option).save_and_record_voter_participation

      expect(described_class.states_by_poll_id(polls: [poll], user: user))
        .to eq(poll.id => described_class::PARTLY_ANSWERED)
      expect(described_class.finished?(poll: poll, user: user)).to be false
    end
  end
end
