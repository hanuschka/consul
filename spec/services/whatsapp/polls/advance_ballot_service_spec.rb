require "rails_helper"

describe Whatsapp::Polls::AdvanceBallotService do
  let(:user) { create(:user) }
  let(:account) { Whatsapp::Account.create!(wa_id: "4915100000001", user: user) }
  let(:conversation) { Whatsapp::Conversation.create!(whatsapp_account: account) }
  let(:poll) { create(:poll, name: "WhatsApp-Test: Kartenpunkt") }
  let!(:map_question) { create(:poll_question, :map_points, poll: poll, title: "Kartenpunkt") }

  let(:continuation) { Whatsapp::AiAssistant::ContinueConversationService::CARRIED_ON }

  def advance
    described_class.call(conversation: conversation, poll: poll)
  end

  def handed_note
    handed = nil

    expect(Whatsapp::AiAssistant::ContinueConversationService)
      .to have_received(:call) { |**arguments| handed = arguments[:note] }

    handed
  end

  def sent_body
    sent = nil

    expect(Whatsapp::Send).to have_received(:text) { |**arguments| sent = arguments[:body] }

    sent
  end

  before do
    allow(Whatsapp::VotableBallotQuery).to receive(:for).and_return(poll)
    allow(Whatsapp::AiAssistant::ContinueConversationService)
      .to receive(:call).and_return(continuation)
    allow(Whatsapp::AiAssistant::BotCopyService).to receive(:line) { |account:, body:| body }
    allow(Whatsapp::Send).to receive(:text)

    conversation.store_active_poll!(poll.id)
  end

  context "when every question was skipped" do
    before { conversation.decline_poll_question!(map_question.id) }

    it "ends as skipped, with no answer stored" do
      expect(advance).to eq described_class::SKIPPED
      expect(Poll::Answer.where(author: user)).to be_empty
    end

    it "never tells the assistant that answers were recorded" do
      advance

      expect(handed_note).to include("not one answer of theirs is recorded")
      expect(handed_note).not_to include("every answer of theirs is recorded")
    end

    it "drops the declined markers, so starting the vote again asks the question again" do
      advance

      expect(conversation.reload.declined_poll_question_ids).to be_empty
      expect(conversation.active_poll_id).to be_nil
    end

    context "when the assistant cannot be reached" do
      let(:continuation) { Whatsapp::AiAssistant::ContinueConversationService::UNAVAILABLE }

      it "says nothing was saved and that the vote is still open" do
        advance

        expect(sent_body).to eq Whatsapp.copy("whatsapp.bot.poll.skipped.open_ended", poll: poll.name)
      end

      it "names the day the vote closes where the phase has one" do
        poll.projekt_phase.update_columns(end_date: Date.new(2026, 10, 31))

        advance

        expect(sent_body).to eq Whatsapp.copy(
          "whatsapp.bot.poll.skipped.until_date",
          poll: poll.name,
          date: Whatsapp::DatePhrase.absolute(Date.new(2026, 10, 31))
        )
      end
    end
  end

  context "when some questions were answered and the rest skipped" do
    let!(:choice_question) { create(:poll_question, poll: poll, title: "Lieblingsfarbe") }
    let!(:option) { create(:poll_question_answer, question: choice_question, title: "Blau") }

    before do
      choice_question.find_or_initialize_user_answer(user, option).save_and_record_voter_participation
      conversation.decline_poll_question!(map_question.id)
    end

    it "ends as partly answered" do
      expect(advance).to eq described_class::PARTLY_ANSWERED
    end

    it "hands the assistant the answers given and the question skipped" do
      advance

      expect(handed_note).to include("not answered the vote in full")
      expect(handed_note).to include("- \"Lieblingsfarbe\": \"Blau\"")
      expect(handed_note).to include("- \"Kartenpunkt\"")
    end

    context "when the assistant cannot be reached" do
      let(:continuation) { Whatsapp::AiAssistant::ContinueConversationService::UNAVAILABLE }

      it "confirms the answers given and lists the skipped question as skipped" do
        advance

        expect(sent_body).to start_with(
          Whatsapp.copy("whatsapp.bot.poll.partly_answered.open_ended", poll: poll.name)
        )
        expect(sent_body).to include("*Lieblingsfarbe*\nBlau")
        expect(sent_body).to include(
          "*Kartenpunkt*\n#{Whatsapp.copy("whatsapp.bot.poll.summary_skipped")}"
        )
      end
    end
  end

  context "when every question was answered" do
    before do
      answer = map_question.answers.create!(author: user)

      3.times { answer.map_points.create!(latitude: 51.5, longitude: 7.4) }
    end

    it "ends as completed and confirms the vote" do
      expect(advance).to eq described_class::COMPLETED
      expect(handed_note).to include("every answer of theirs is recorded")
    end
  end
end
