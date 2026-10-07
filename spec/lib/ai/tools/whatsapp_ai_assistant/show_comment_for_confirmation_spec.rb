require "rails_helper"

describe Ai::Tools::WhatsappAiAssistant::ShowCommentForConfirmation do
  # The comment's counterpart of the draft preview's guarantees: one preview per
  # version and message, and a posting pill that says which version it stood under.
  subject(:tool) do
    Ai::Tools::WhatsappAiAssistant::ShowCommentForConfirmation.new(conversation: conversation)
  end

  let(:account) { double(:account) }
  let(:digest) { "0f0e0d0c0b0a09080706050403020100ffeeddccbbaa99887766554433221100" }
  let(:claimed) { true }

  let(:conversation) do
    double(
      :conversation,
      pending_comment: { "proposal_id" => 4821, "text" => "Gute Idee" },
      whatsapp_account: account,
      user: nil,
      step: "comment"
    ).tap do |stub|
      allow(stub).to receive(:claim_preview!).and_return(claimed)
      allow(stub).to receive(:store_comment_preview_digest!)
    end
  end

  def show
    tool.execute(
      question: "Soll er so auf die Seite?",
      buttons: [{ "action_id" => "comment_post", "label" => "" }]
    )
  end

  before do
    allow(Whatsapp::CommentPreview).to receive(:confirmation_block).and_return("Gute Idee")
    allow(Whatsapp::CommentPreview).to receive(:digest).and_return(digest)
    allow(Whatsapp::AiAssistant::DecisionLog).to receive(:record)
    allow(Whatsapp::Send).to receive(:message_block)
    allow(Whatsapp::Send).to receive(:buttons)
  end

  it "claims the version it shows under the current message" do
    show

    expect(conversation).to have_received(:claim_preview!).with(kind: :comment, digest: digest)
  end

  it "tags the posting pill with the version it was offered under" do
    show

    expect(Whatsapp::Send).to have_received(:buttons) do |buttons:, **|
      expect(buttons.map { |button| button[:id] })
        .to eq(["whatsapp_flow_comment_post-0f0e0d0c0b0a"])
    end
  end

  context "when this version was already shown in answer to this message" do
    let(:claimed) { false }

    it "sends nothing and still ends the turn" do
      expect(show).to be_a(ToolHalt)
      expect(Whatsapp::Send).not_to have_received(:message_block)
      expect(Whatsapp::Send).not_to have_received(:buttons)
    end
  end
end
