require "rails_helper"

describe Ai::Tools::WhatsappAiAssistant::ShowDraftForConfirmation do
  # One change to a draft, one preview — and the publishing pill under it says which
  # version it was offered under, so a tap under an older preview can be told apart.
  subject(:tool) do
    Ai::Tools::WhatsappAiAssistant::ShowDraftForConfirmation.new(conversation: conversation)
  end

  let(:account) { double(:account) }
  let(:resource) { double(:resource, image: nil) }
  let(:digest) { "a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0c1d2e3f4a5b6c7d8e9f0a1b2" }
  let(:claimed) { true }

  let(:conversation) do
    double(
      :conversation,
      draft_resource: resource,
      whatsapp_account: account,
      user: nil,
      additions_beyond_idea: [],
      image_question_settled?: true,
      location_question_open?: false,
      step: "idle"
    ).tap do |stub|
      allow(stub).to receive(:claim_preview!).and_return(claimed)
      allow(stub).to receive(:store_draft_preview_digest!)
    end
  end

  let(:buttons) { [{ "action_id" => "draft_publish", "label" => "" }] }

  def show
    tool.execute(question: "Soll er so veröffentlicht werden?", buttons: buttons)
  end

  before do
    allow(Whatsapp::DraftPreview).to receive(:confirmation_block).and_return("*Titel*\n\nText")
    allow(Whatsapp::DraftPreview).to receive(:digest).and_return(digest)
    allow(Whatsapp::AiAssistant::DecisionLog).to receive(:record)
    allow(Whatsapp::Send).to receive(:text)
    allow(Whatsapp::Send).to receive(:buttons)
  end

  it "sends the draft and the question under it" do
    show

    expect(Whatsapp::Send).to have_received(:text).with(account: account, body: "*Titel*\n\nText")
    expect(Whatsapp::Send).to have_received(:buttons).once
  end

  it "claims the version it shows under the current message" do
    show

    expect(conversation).to have_received(:claim_preview!).with(kind: :draft, digest: digest)
  end

  it "ends the turn" do
    expect(show).to be_a(ToolHalt)
  end

  it "tags the publishing pill with the version it was offered under" do
    show

    expect(Whatsapp::Send).to have_received(:buttons) do |buttons:, **|
      expect(buttons.map { |button| button[:id] })
        .to eq(["whatsapp_flow_draft_publish-a1b2c3d4e5f6"])
    end
  end

  context "when this version was already shown in answer to this message" do
    let(:claimed) { false }

    it "sends nothing" do
      show

      expect(Whatsapp::Send).not_to have_received(:text)
      expect(Whatsapp::Send).not_to have_received(:buttons)
    end

    # Handed an error, the model would write a reply on top of the preview.
    it "still ends the turn" do
      expect(show).to be_a(ToolHalt)
    end

    it "stores no digest of its own" do
      show

      expect(conversation).not_to have_received(:store_draft_preview_digest!)
    end

    it "records the preview it held back" do
      show

      expect(Whatsapp::AiAssistant::DecisionLog)
        .to have_received(:record).with(hash_including(event: :preview_repeated, kind: :draft))
    end
  end

  # The pill that takes the additions out goes right after the publishing pill,
  # which is found by its action now that its id carries the version.
  context "when the draft carries additions beyond the citizen's words" do
    let(:conversation) do
      double(
        :conversation,
        draft_resource: resource,
        whatsapp_account: account,
        user: nil,
        additions_beyond_idea: ["eine Bank"],
        image_question_settled?: true,
        location_question_open?: false,
        step: "idle"
      ).tap do |stub|
        allow(stub).to receive(:claim_preview!).and_return(true)
        allow(stub).to receive(:store_draft_preview_digest!)
      end
    end

    it "puts the publishing pill first and the one that removes the additions after it" do
      tool.execute(
        question: "Soll er so veröffentlicht werden?",
        additions_note: "Die Bank habe ich ergänzt.",
        buttons: buttons
      )

      expect(Whatsapp::Send).to have_received(:buttons) do |buttons:, **|
        expect(buttons.map { |button| button[:id] }).to eq(
          ["whatsapp_flow_draft_publish-a1b2c3d4e5f6", "whatsapp_flow_remove_additions"]
        )
      end
    end
  end
end
