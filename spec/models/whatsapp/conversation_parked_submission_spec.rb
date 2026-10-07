require "rails_helper"

describe Whatsapp::Conversation do
  # A contribution asked for while a draft or a comment was still open. It has to
  # outlive the discard the citizen agrees to, and the draft they finish instead,
  # or the idea they gave with the request is gone again.
  describe "a parked contribution" do
    let(:context) { { "draft_data" => { "title" => "Mehr Bäume" }} }

    let(:conversation) { Whatsapp::Conversation.new(context: context, projekt_phase_id: 1) }

    let(:other_phase) { double(:projekt_phase, id: 2) }

    let(:idea) { "Ich möchte bei der Jugendbeteiligung vorschlagen: Trinkbrunnen am Skaterpark" }

    before do
      allow(conversation).to receive(:update!) do |attributes|
        conversation.assign_attributes(attributes)
      end
      allow(ProjektPhase).to receive(:find_by).with(id: 2).and_return(other_phase)

      conversation.park_submission!(projekt_phase: other_phase, text: idea)
    end

    it "holds the projekt phase asked for" do
      expect(conversation.parked_projekt_phase).to eq(other_phase)
    end

    it "holds the citizen's words as they wrote them" do
      expect(conversation.parked_submission_text).to eq(idea)
    end

    it "outlives the discard of the open draft" do
      conversation.discard_draft!

      expect(conversation.parked_projekt_phase).to eq(other_phase)
    end

    it "outlives the open draft being published instead" do
      conversation.complete_draft!

      expect(conversation.parked_submission_text).to eq(idea)
    end

    it "goes once a new submission is started" do
      conversation.start_draft!(nil)

      expect(conversation.parked_projekt_phase).to be_nil
    end

    it "goes with a request to start over" do
      conversation.begin_start_over!

      expect(conversation.parked_projekt_phase).to be_nil
    end

    # Picked from a list, the projekt comes without any words.
    context "without words" do
      before { conversation.park_submission!(projekt_phase: other_phase, text: "  ") }

      it "holds no text" do
        expect(conversation.parked_submission_text).to be_nil
      end
    end
  end
end
