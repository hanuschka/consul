require "rails_helper"

describe Ai::Tools::WhatsappAiAssistant::AbortSubmission do
  subject(:tool) do
    Ai::Tools::WhatsappAiAssistant::AbortSubmission.new(conversation: conversation)
  end

  let(:unsaved_submission) { true }

  let(:start_over_requested) { false }

  let(:conversation) do
    double(
      :conversation,
      unsaved_submission?: unsaved_submission,
      start_over_requested?: start_over_requested
    ).tap { |stub| allow(stub).to receive(:discard_draft!) }
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

  describe "when nothing is in progress" do
    let(:unsaved_submission) { false }

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
end
