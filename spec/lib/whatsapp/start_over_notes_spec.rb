require "rails_helper"

describe Whatsapp::StartOverNotes do
  subject(:note) { Whatsapp::StartOverNotes.for(conversation) }

  let(:unsaved_submission) { false }

  let(:pending_comment) { nil }

  let(:conversation) do
    double(:conversation, unsaved_submission?: unsaved_submission, pending_comment: pending_comment)
  end

  let(:written_comment) { { "proposal_id" => 7, "text" => "Gute Idee" } }

  it "gives the fresh start where nothing is written" do
    expect(note).to eq(Whatsapp::StartOverNotes::WITHOUT_DRAFT)
  end

  context "with a contribution half-written" do
    let(:unsaved_submission) { true }

    it "asks about the draft" do
      expect(note).to eq(Whatsapp::StartOverNotes::WITH_DRAFT)
    end
  end

  context "with a comment written and not posted" do
    let(:pending_comment) { written_comment }

    it "asks about the comment" do
      expect(note).to eq(Whatsapp::StartOverNotes::WITH_COMMENT)
    end
  end

  # One question, because one discard takes both.
  context "with both" do
    let(:unsaved_submission) { true }

    let(:pending_comment) { written_comment }

    it "asks about both at once" do
      expect(note).to eq(Whatsapp::StartOverNotes::WITH_DRAFT_AND_COMMENT)
    end
  end
end
