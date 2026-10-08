require "rails_helper"

describe Whatsapp::CompletionNotes do
  let(:closes_on) { Date.current + 30 }
  let(:poll) { create(:poll, name: "WhatsApp-Test: Kartenpunkt") }
  let(:question) { create(:poll_question, :map_points, poll: poll, title: "Kartenpunkt") }

  before do
    poll.projekt_phase.update_columns(end_date: closes_on)

    allow(Whatsapp::ProjektLink).to receive(:poll_ballot_url).and_return("https://example.test/ballot")
  end

  def ending(outcome:, answers: [], unanswered_questions: [])
    Whatsapp::Polls::BallotEndingQuery::Ending.new(
      poll: poll, outcome: outcome, answers: answers, unanswered_questions: unanswered_questions
    )
  end

  describe ".ballot_ended" do
    it "tells a ballot skipped whole that it is still open until it closes" do
      note = described_class.ballot_ended(
        ending(outcome: Whatsapp::Polls::AdvanceBallotService::SKIPPED, unanswered_questions: [question])
      )

      expect(note).to include("not one answer of theirs is recorded")
      expect(note).to include("do not thank them for voting")
      expect(note).to include(Whatsapp::DatePhrase.absolute(closes_on))
      expect(note).to include("https://example.test/ballot")
    end

    it "lists no skipped question where every question holds some answer" do
      partial_map = Whatsapp::Polls::BallotSummaryQuery::Entry.new(
        question: question, answers: [], map_points: 1
      )

      note = described_class.ballot_ended(
        ending(outcome: Whatsapp::Polls::AdvanceBallotService::PARTLY_ANSWERED, answers: [partial_map])
      )

      expect(note).to include("- \"Kartenpunkt\": 1 place(s) marked on the map")
      expect(note).not_to include("Skipped, with no answer of theirs:")
      expect(note).to include(Whatsapp::DatePhrase.absolute(closes_on))
    end
  end
end
