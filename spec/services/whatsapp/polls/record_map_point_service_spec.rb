require "rails_helper"

describe Whatsapp::Polls::RecordMapPointService do
  let(:user) { create(:user) }
  let(:account) { Whatsapp::Account.create!(wa_id: "4915100000002", user: user) }
  let(:conversation) { Whatsapp::Conversation.create!(whatsapp_account: account) }
  let(:poll) { create(:poll, name: "WhatsApp-Test: Kartenpunkt") }
  let!(:map_question) { create(:poll_question, :map_points, poll: poll, title: "Kartenpunkt") }

  before do
    allow(Whatsapp::VotableBallotQuery).to receive(:for).and_return(poll)
    allow_any_instance_of(ProjektPhase::VotingPhase).to receive(:permission_problem).and_return(nil)
    allow(Whatsapp::AiAssistant::ContinueConversationService).to receive(:call).and_return(
      Whatsapp::AiAssistant::ContinueConversationService::CARRIED_ON
    )

    conversation.store_active_poll!(poll.id)
    conversation.store_pending_map_question!(map_question.id)
  end

  describe ".skip" do
    it "records nothing and ends a ballot of that one question as skipped" do
      outcome = described_class.skip(conversation: conversation)

      expect(outcome).to eq Whatsapp::Polls::AdvanceBallotService::SKIPPED
      expect(Poll::Answer.where(author: user)).to be_empty
      expect(Poll::Voter.where(user: user, poll: poll)).to be_empty
    end

    it "does not report the skipped ballot as a vote taken part in" do
      described_class.skip(conversation: conversation)

      expect(Whatsapp::BallotParticipation.finished?(poll: poll, user: user)).to be false
      expect(Whatsapp::BallotParticipation.states_by_poll_id(polls: [poll], user: user)).to eq({})
    end
  end
end
