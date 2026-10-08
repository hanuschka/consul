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
      image_question_settled?: true,
      location_question_settled?: true,
      step: "idle"
    )
  end

  before do
    allow(Whatsapp::Drafting::ResourceCreationValidationService).to receive(:call).and_return(nil)
    allow(Whatsapp::Drafting::SubmissionAuthorService).to receive(:call).and_return(user)
    allow(Whatsapp::DraftPreview).to receive(:digest).and_return("current-digest")

    allow(conversation).to receive(:confirmation_offered?).and_return(false)
  end

  # Nothing can be added to a published contribution from the chat, so a phase
  # that takes pictures has to have asked for one first.
  describe "the picture question gate" do
    before do
      allow(conversation).to receive(:image_question_settled?).and_return(false)
      allow(conversation).to receive(:confirmation_offered?).and_return(true)
      allow(conversation).to receive(:draft_preview_digest).and_return("current-digest")
    end

    it "refuses when the citizen has not been asked for a picture" do
      answer = tool.execute

      expect(answer[:error]).to match(/has not been asked for one/)
      expect(answer[:hint]).to match(/request_photo/)
    end

    it "does not publish when it refuses" do
      expect(Whatsapp::Drafting::CompleteDraftService).not_to receive(:call)

      tool.execute
    end

    it "lets an answered picture question through" do
      allow(conversation).to receive(:image_question_settled?).and_return(true)

      expect(Whatsapp::Drafting::CompleteDraftService)
        .to receive(:call)
        .and_return(double(:stored, invalid?: true, errors: []))

      tool.execute
    end
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
    let(:proposal) { instance_double(Proposal, id: 77, is_a?: true, admin_accepted?: true) }

    before do
      allow(conversation).to receive(:confirmation_offered?).and_return(true)
      allow(conversation).to receive(:draft_preview_digest).and_return("current-digest")
      allow(conversation).to receive(:complete_draft!)
      allow(conversation).to receive(:note_submission_completed!)

      allow(Whatsapp::Drafting::CompleteDraftService).to receive(:call).and_return(
        double(:stored, invalid?: false, missing?: false, resource: proposal)
      )
      allow(Whatsapp::Drafting::PublishDraftService).to receive(:call).and_return(proposal)
      allow(Whatsapp::PublishedResourceUrl).to receive(:call).and_return("https://example.org/p/1")
      allow(Whatsapp::DraftPreview).to receive(:published_confirmation).and_return("published")
      allow(Whatsapp::Send).to receive(:message_block)
    end

    it "publishes" do
      expect(tool.execute[:published]).to be(true)
    end

    it "sends where it went, with the platform's own address" do
      expect(Whatsapp::DraftPreview)
        .to receive(:published_confirmation)
        .with(conversation: conversation, url: "https://example.org/p/1")
        .and_return("published")
      expect(Whatsapp::Send).to receive(:message_block).with(account: account, block: "published")

      tool.execute
    end

    it "sends the confirmation before the draft is dropped" do
      expect(Whatsapp::DraftPreview).to receive(:published_confirmation).ordered
      expect(conversation).to receive(:complete_draft!).ordered

      tool.execute
    end

    # The reply after it carries the next steps after a submission
    # (Whatsapp::StatePills).
    it "puts the completed submission in focus for the reply" do
      tool.execute

      expect(Current.whatsapp_pill_focus).to eq(submission_completed: true)
    ensure
      Current.reset
    end

    context "when the phase holds contributions for review" do
      let(:proposal) { instance_double(Proposal, id: 77, is_a?: true, admin_accepted?: false) }

      before do
        allow(Whatsapp::DraftPreview).to receive(:awaiting_review_confirmation).and_return("held")
      end

      it "offers no address" do
        expect(tool.execute[:url]).to be_nil
      end

      it "says plainly that it is waiting rather than sending the published confirmation" do
        expect(Whatsapp::DraftPreview).to receive(:awaiting_review_confirmation)
        expect(Whatsapp::DraftPreview).not_to receive(:published_confirmation)

        tool.execute
      end
    end
  end
end
