require "rails_helper"

describe Ai::Tools::WhatsappAiAssistant::StartOver do
  subject(:tool) { Ai::Tools::WhatsappAiAssistant::StartOver.new(conversation: conversation) }

  let(:pending_comment) { nil }

  let(:conversation) do
    double(
      :conversation,
      unsaved_submission?: false,
      unsaved_work?: pending_comment.present?,
      pending_comment: pending_comment
    ).tap { |stub| allow(stub).to receive(:begin_start_over!) }
  end

  before { allow(Whatsapp::AiAssistant::DecisionLog).to receive(:record) }

  it "starts over the way the pill does" do
    tool.execute

    expect(conversation).to have_received(:begin_start_over!)
  end

  it "gives the fresh start where nothing is written" do
    expect(tool.execute[:hint]).to eq(Whatsapp::StartOverNotes::WITHOUT_DRAFT)
  end

  context "when a comment is written and not posted" do
    let(:pending_comment) { { "proposal_id" => 7, "text" => "Gute Idee" } }

    it "asks about the comment before anything is discarded" do
      expect(tool.execute[:hint]).to eq(Whatsapp::StartOverNotes::WITH_COMMENT)
    end

    it "leaves the step where the comment had it" do
      expect(tool.diagnostic_step).to be_nil
    end

    it "records that something unsaved was in the way" do
      tool.execute

      expect(Whatsapp::AiAssistant::DecisionLog)
        .to have_received(:record).with(hash_including(event: :start_over, unsaved: true))
    end
  end
end
