require "rails_helper"

describe Whatsapp::DiscardNotes do
  subject(:note) { Whatsapp::DiscardNotes.for(conversation) }

  let(:unsaved_submission) { true }

  let(:parked_projekt_phase) { nil }

  let(:parked_text) { nil }

  let(:other_projekt) { double(:projekt) }

  let(:other_phase) { double(:projekt_phase, id: 42, projekt: other_projekt) }

  let(:idea) { "Ich möchte bei der Jugendbeteiligung vorschlagen: Trinkbrunnen am Skaterpark" }

  let(:conversation) do
    double(
      :conversation,
      unsaved_submission?: unsaved_submission,
      draft_resource: nil,
      draft_data: { "title" => "Mehr Bänke" },
      projekt_phase: nil,
      pending_comment: nil,
      active_poll_id: nil,
      pending_poll_id: nil,
      step_in_progress?: unsaved_submission,
      parked_projekt_phase: parked_projekt_phase,
      parked_submission_text: parked_text
    )
  end

  before do
    allow(Whatsapp::ProjektLink).to receive(:title).with(other_projekt).and_return("Jugendbeteiligung")
  end

  it "names the discarded draft and offers a way on" do
    expect(note).to eq(
      "Their draft contribution \"Mehr Bänke\" has been discarded; it is gone and cannot be " \
      "recovered. #{Whatsapp::DiscardNotes::REPLY}"
    )
  end

  # The bug: the discard was the yes to leaving the draft for another projekt, and
  # the reply ended on "abgebrochen" with the new idea gone.
  context "when it was left for a contribution to another projekt" do
    let(:parked_projekt_phase) { other_phase }

    let(:parked_text) { idea }

    it "carries on with that contribution rather than offering a choice" do
      expect(note).to include(Whatsapp::DiscardNotes::PARKED_REPLY)
      expect(note).not_to include(Whatsapp::DiscardNotes::REPLY)
    end

    it "hands over the citizen's words whole" do
      expect(note).to include("\"#{idea}\"")
    end

    it "names the projekt and the phase to start" do
      expect(note).to include("Jugendbeteiligung")
      expect(note).to include("projekt_phase_id 42")
    end

    it "still says what was discarded" do
      expect(note).to start_with("Their draft contribution \"Mehr Bänke\" has been discarded")
    end
  end

  # Picked from a list: the projekt is known, the idea is not yet.
  context "when the other projekt was picked without words" do
    let(:parked_projekt_phase) { other_phase }

    it "asks only for the idea" do
      expect(note).to include("without saying what yet: start it and ask for their idea")
    end
  end

  context "when nothing was in progress" do
    let(:unsaved_submission) { false }

    let(:parked_projekt_phase) { other_phase }

    it "does not report a discard" do
      expect(note).to eq(Whatsapp::DiscardNotes::NOTHING)
    end
  end
end
