require "rails_helper"

describe Ai::Tools::WhatsappAiAssistant::StartDraft do
  subject(:tool) do
    Ai::Tools::WhatsappAiAssistant::StartDraft.new(
      conversation: conversation, citizen_words: citizen_words
    )
  end

  let(:idea) { "Ich möchte bei der Jugendbeteiligung vorschlagen: Trinkbrunnen am Skaterpark" }

  let(:citizen_words) { idea }

  let(:unsaved_submission) { false }

  let(:pending_comment) { nil }

  let(:other_phase) { double(:projekt_phase, id: 42) }

  let(:conversation) do
    double(
      :conversation,
      unsaved_submission?: unsaved_submission,
      unsaved_work?: unsaved_submission || pending_comment.present?,
      projekt_phase: nil
    ).tap do |stub|
      allow(stub).to receive(:park_submission!)
      allow(stub).to receive(:start_draft!)
    end
  end

  before do
    allow(ProjektPhase).to receive_message_chain(:includes, :find_by).and_return(other_phase)
    allow(Whatsapp::EligiblePhasesQuery).to receive(:eligible?).with(other_phase).and_return(true)
  end

  context "with nothing open" do
    it "starts the submission" do
      tool.execute(projekt_phase_id: 42)

      expect(conversation).to have_received(:start_draft!).with(other_phase)
    end

    it "parks nothing" do
      tool.execute(projekt_phase_id: 42)

      expect(conversation).not_to have_received(:park_submission!)
    end
  end

  context "while a draft is open" do
    let(:unsaved_submission) { true }

    it "starts nothing" do
      tool.execute(projekt_phase_id: 42)

      expect(conversation).not_to have_received(:start_draft!)
    end

    # The bug: the idea came with the request and was gone after the discard.
    it "keeps the projekt and the citizen's words for after the question" do
      tool.execute(projekt_phase_id: 42)

      expect(conversation).to have_received(:park_submission!).with(projekt_phase: other_phase, text: idea)
    end

    it "asks whether to discard or keep the open one" do
      expect(tool.execute(projekt_phase_id: 42)[:hint]).to include("ask whether to discard it or keep it")
    end

    it "says how the new one comes back when the open one is kept" do
      expect(tool.execute(projekt_phase_id: 42)[:hint])
        .to include("come back to it once the other is published or discarded")
    end

    # Picked from a list, the turn answers a tap rather than words they wrote.
    context "when the projekt was picked rather than written" do
      let(:citizen_words) { nil }

      it "keeps the projekt without words" do
        tool.execute(projekt_phase_id: 42)

        expect(conversation).to have_received(:park_submission!).with(projekt_phase: other_phase, text: nil)
      end
    end
  end

  # A comment written and not posted used to be replaced along with the rest of the
  # context, without a word.
  context "while a comment is written and not posted" do
    let(:pending_comment) { { "proposal_id" => 7, "text" => "Gute Idee" } }

    it "starts nothing" do
      tool.execute(projekt_phase_id: 42)

      expect(conversation).not_to have_received(:start_draft!)
    end

    it "keeps what they asked for" do
      tool.execute(projekt_phase_id: 42)

      expect(conversation).to have_received(:park_submission!).with(projekt_phase: other_phase, text: idea)
    end

    it "names the comment as what is open" do
      expect(tool.execute(projekt_phase_id: 42)[:error]).to include("part-way through a comment")
    end
  end
end
