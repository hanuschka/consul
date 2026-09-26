require "rails_helper"

describe Ai::Tools::WhatsappAiAssistant::PublishDraft do
  # The two guarantees this tool carries and nothing else does: a citizen cannot
  # have something published they were never shown, and cannot have a revision
  # published on a yes they gave to the version before it.
  subject(:tool) { Ai::Tools::WhatsappAiAssistant::PublishDraft.new(conversation: conversation) }

  let(:user) { double(:user) }
  let(:account) { double(:account, user: user, terms_accepted?: true) }
  let(:projekt_phase) { double(:projekt_phase, id: 7) }
  let(:resource) { double(:resource) }

  let(:conversation) do
    double(
      :conversation,
      unsaved_submission?: true,
      whatsapp_account: account,
      projekt_phase: projekt_phase,
      projekt_phase_id: projekt_phase.id,
      draft_resource: resource,
      draft_preview_digest: nil,
      step: "idle"
    )
  end

  before do
    allow(Whatsapp::Drafting::ResourceCreationValidationService).to receive(:call).and_return(nil)
    allow(Whatsapp::Drafting::SubmissionAuthorService).to receive(:call).and_return(user)
    allow(Whatsapp::DraftPreview).to receive(:digest).and_return("current-digest")

    allow(conversation).to receive(:confirmation_offered?).and_return(false)
  end

  describe "the confirmation gate" do
    it "refuses when no publish button was offered on an earlier message" do
      answer = tool.execute

      expect(answer[:error]).to match(/has not been shown this draft/)
      expect(answer[:hint]).to match(/show_draft_for_confirmation/)
    end

    it "does not publish when it refuses" do
      expect(Whatsapp::Drafting::CompleteDraftService).not_to receive(:call)

      tool.execute
    end
  end

  describe "the stale-preview gate" do
    before { allow(conversation).to receive(:confirmation_offered?).and_return(true) }

    it "refuses when nothing has been shown to the citizen at all" do
      answer = tool.execute

      expect(answer[:error]).to match(/has changed since the citizen was last shown it/)
    end

    # The revision case: the offer survives on the record, and only the digest
    # separates a yes to this text from a yes to the text before it.
    it "refuses when the draft has moved on since the citizen was shown it" do
      allow(conversation).to receive(:draft_preview_digest).and_return("digest-of-the-old-text")

      answer = tool.execute

      expect(answer[:error]).to match(/has changed since the citizen was last shown it/)
      expect(answer[:hint]).to match(/show_draft_for_confirmation/)
    end

    it "does not publish when it refuses" do
      allow(conversation).to receive(:draft_preview_digest).and_return("digest-of-the-old-text")

      expect(Whatsapp::Drafting::CompleteDraftService).not_to receive(:call)

      tool.execute
    end
  end

  describe "once the citizen has confirmed the draft as it stands" do
    let(:proposal) { instance_double(Proposal, is_a?: true, admin_accepted?: true) }

    before do
      allow(conversation).to receive(:confirmation_offered?).and_return(true)
      allow(conversation).to receive(:draft_preview_digest).and_return("current-digest")
      allow(conversation).to receive(:complete_draft!)

      allow(Whatsapp::Drafting::CompleteDraftService).to receive(:call).and_return(
        double(:stored, invalid?: false, missing?: false, resource: proposal)
      )
      allow(Whatsapp::Drafting::PublishDraftService).to receive(:call).and_return(proposal)
      allow(Whatsapp::PublishedResourceUrl).to receive(:call).and_return("https://example.org/p/1")
      allow(Whatsapp::DraftPreview).to receive(:published_block).and_return("the contribution")
      allow(Whatsapp::DraftPreview).to receive(:chunks).and_return(["the contribution"])
      allow(Whatsapp::Send).to receive(:text)
    end

    it "publishes" do
      expect(tool.execute[:published]).to be(true)
    end

    it "sends the contribution back composed from the record, not described to the model" do
      expect(Whatsapp::Send)
        .to receive(:text)
        .with(account: account, body: "the contribution")

      tool.execute
    end

    it "sends the recap before the draft is dropped" do
      expect(Whatsapp::DraftPreview).to receive(:published_block).ordered
      expect(conversation).to receive(:complete_draft!).ordered

      tool.execute
    end

    context "when the phase holds contributions for review" do
      let(:proposal) { instance_double(Proposal, is_a?: true, admin_accepted?: false) }

      before do
        allow(Whatsapp::DraftPreview).to receive(:awaiting_review_block).and_return("held")
        allow(Whatsapp::DraftPreview).to receive(:chunks).and_return(["held"])
      end

      it "offers no address" do
        expect(tool.execute[:url]).to be_nil
      end

      it "says plainly that it is waiting rather than sending the published block" do
        expect(Whatsapp::DraftPreview).to receive(:awaiting_review_block)
        expect(Whatsapp::DraftPreview).not_to receive(:published_block)

        tool.execute
      end
    end
  end
end
