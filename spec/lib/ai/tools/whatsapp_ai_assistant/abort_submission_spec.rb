require "rails_helper"

describe Ai::Tools::WhatsappAiAssistant::AbortSubmission do
  subject(:tool) do
    Ai::Tools::WhatsappAiAssistant::AbortSubmission.new(conversation: conversation)
  end

  let(:step_in_progress) { true }

  let(:start_over_requested) { false }

  let(:revision_open) { false }

  let(:parked_projekt_phase) { nil }

  let(:conversation) do
    double(
      :conversation,
      step_in_progress?: step_in_progress,
      start_over_requested?: start_over_requested,
      revision_open?: revision_open,
      unsaved_submission?: false,
      pending_comment: nil,
      active_poll_id: nil,
      pending_poll_id: nil,
      parked_projekt_phase: parked_projekt_phase,
      parked_submission_text: "Trinkbrunnen am Skaterpark"
    ).tap do |stub|
      allow(stub).to receive(:discard_draft!)
      allow(stub).to receive(:revert_revision!)
    end
  end

  describe "an ordinary abandonment" do
    it "discards the draft" do
      tool.execute

      expect(conversation).to have_received(:discard_draft!)
    end

    # Somebody who has just given up is not owed a list of what else there is.
    it "does not go on to offer what the portal has" do
      expect(tool.execute[:hint]).to include("Do not list what else the portal offers")
    end
  end

  # The yes was to leaving it for a contribution asked for elsewhere, so the answer
  # carries on with that one rather than ending on what was lost.
  describe "an abandonment for a contribution to another projekt" do
    let(:other_projekt) { double(:projekt) }

    let(:parked_projekt_phase) { double(:projekt_phase, id: 42, projekt: other_projekt) }

    before do
      allow(Whatsapp::ProjektLink).to receive(:title).with(other_projekt).and_return("Jugendbeteiligung")
    end

    it "discards the draft" do
      tool.execute

      expect(conversation).to have_received(:discard_draft!)
    end

    it "carries on with the contribution asked for" do
      hint = tool.execute[:hint]

      expect(hint).to include("start_draft with projekt_phase_id 42")
      expect(hint).to include("\"Trinkbrunnen am Skaterpark\"")
      expect(hint).to include(Whatsapp::DiscardNotes::PARKED_REPLY)
    end

    it "reads it before the discard" do
      expect(conversation).to receive(:parked_projekt_phase).ordered
      expect(conversation).to receive(:discard_draft!).ordered

      tool.execute
    end
  end

  describe "when nothing is in progress" do
    let(:step_in_progress) { false }

    it "discards nothing" do
      tool.execute

      expect(conversation).not_to have_received(:discard_draft!)
    end

    it "says so, rather than reporting a discard that did not happen" do
      expect(tool.execute[:discarded]).to be false
    end
  end

  # The discard was the price of a request to go back to the beginning, made in an
  # earlier turn. Ending on "it is gone" would leave the citizen exactly where the
  # menu pill used to leave them.
  describe "when the discard was asked for as a way back to the start" do
    let(:start_over_requested) { true }

    it "still discards the draft" do
      tool.execute

      expect(conversation).to have_received(:discard_draft!)
    end

    it "asks for the fresh start that was requested" do
      expect(tool.execute[:hint]).to include("what is open to take part in right now")
    end

    it "keeps the projekt they left out of it" do
      expect(tool.execute[:hint]).to include("Do not offer the projekt they have just left")
    end

    it "reports which of the two answers it gave" do
      expect(tool.execute[:started_over]).to be true
    end

    # Read before the discard, which replaces the context the flag lives in.
    it "reads the request before the context is replaced" do
      expect(conversation).to receive(:start_over_requested?).ordered
      expect(conversation).to receive(:discard_draft!).ordered

      tool.execute
    end
  end

  # The yes to going back to the beginning was a yes to losing what they wrote, so
  # a change still open to their comment is not all that goes.
  describe "when a start-over waits while a change to the comment is open" do
    let(:start_over_requested) { true }

    let(:revision_open) { true }

    it "discards the whole comment" do
      tool.execute

      expect(conversation).to have_received(:discard_draft!)
    end

    it "does not stop at taking back the change" do
      tool.execute

      expect(conversation).not_to have_received(:revert_revision!)
    end
  end
end
