require "rails_helper"

describe Whatsapp::Polls::RecordOpenAnswerService do
  let(:user) { create(:user) }
  let(:account) { Whatsapp::Account.create!(wa_id: "4915100000003", user: user) }
  let(:conversation) { Whatsapp::Conversation.create!(whatsapp_account: account) }
  let(:poll) { create(:poll, name: "WhatsApp-Test: Freitext") }
  let!(:open_question) { create(:poll_question, poll: poll, title: "Ihre Idee") }
  let!(:open_option) do
    create(:poll_question_answer, :open_answer, question: open_question, title: "Eigene Antwort")
  end

  before do
    allow(Whatsapp::VotableBallotQuery).to receive(:for).and_return(poll)
    allow_any_instance_of(ProjektPhase::VotingPhase).to receive(:permission_problem).and_return(nil)
    allow(Whatsapp::AiAssistant::ContinueConversationService).to receive(:call).and_return(
      Whatsapp::AiAssistant::ContinueConversationService::CARRIED_ON
    )

    conversation.store_active_poll!(poll.id)
    conversation.store_pending_open_question!(open_question.id)
  end

  describe ".skip" do
    it "records nothing and ends a ballot of that one question as skipped" do
      outcome = described_class.skip(conversation: conversation)

      expect(outcome).to eq Whatsapp::Polls::AdvanceBallotService::SKIPPED
      expect(Poll::Answer.where(author: user)).to be_empty
    end

    it "removes an earlier answer and the participation it recorded" do
      answer = open_question.find_or_initialize_user_answer(user, open_option)
      answer.save_and_record_voter_participation
      answer.update!(open_answer_text: "Mehr Bänke")

      outcome = described_class.skip(conversation: conversation)

      expect(outcome).to eq Whatsapp::Polls::AdvanceBallotService::SKIPPED
      expect(Poll::Answer.where(author: user)).to be_empty
      expect(Poll::Voter.where(user: user, poll: poll)).to be_empty
    end
  end
end
