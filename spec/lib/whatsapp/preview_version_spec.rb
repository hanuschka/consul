require "rails_helper"

describe Whatsapp::PreviewVersion do
  # A publishing pill stays tappable under every preview the citizen was ever sent,
  # so the pill has to say which version it was offered under — or a tap under the
  # older of two previews answers for a text that is no longer the one going in.
  let(:conversation) { double(:conversation) }

  let(:draft_digest) { "a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0c1d2e3f4a5b6c7d8e9f0a1b2" }
  let(:comment_digest) { "0f0e0d0c0b0a09080706050403020100ffeeddccbbaa99887766554433221100" }

  before do
    allow(Whatsapp::DraftPreview).to receive(:digest).with(conversation: conversation)
      .and_return(draft_digest)
    allow(Whatsapp::CommentPreview).to receive(:digest).with(conversation: conversation)
      .and_return(comment_digest)
  end

  describe ".tag" do
    it "tags both draft publishing pills with the draft's version" do
      %i[draft_publish submit_final].each do |action|
        expect(Whatsapp::PreviewVersion.tag(action: action, conversation: conversation))
          .to eq("a1b2c3d4e5f6")
      end
    end

    it "tags the posting pill with the comment's version" do
      expect(Whatsapp::PreviewVersion.tag(action: :comment_post, conversation: conversation))
        .to eq("0f0e0d0c0b0a")
    end

    it "tags no other pill" do
      expect(Whatsapp::PreviewVersion.tag(action: :draft_revise, conversation: conversation))
        .to be_nil
    end

    it "fits the shape a pill id's parameter is parsed with" do
      tag = Whatsapp::PreviewVersion.tag(action: :draft_publish, conversation: conversation)
      id = Whatsapp::FlowActions.id_for(action: :draft_publish, param: tag)

      expect(Whatsapp::FlowActions.parse(id)).to eq(action: :draft_publish, param: tag)
    end

    context "when there is nothing to publish" do
      let(:draft_digest) { nil }

      it "tags nothing" do
        expect(Whatsapp::PreviewVersion.tag(action: :draft_publish, conversation: conversation))
          .to be_nil
      end
    end
  end

  describe ".outdated?" do
    def outdated?(param, action: :draft_publish)
      Whatsapp::PreviewVersion.outdated?(action: action, param: param, conversation: conversation)
    end

    it "is false for a pill offered under the version that stands" do
      expect(outdated?("a1b2c3d4e5f6")).to be(false)
    end

    it "is true for a pill offered under an earlier version" do
      expect(outdated?("999999999999")).to be(true)
    end

    it "compares a posting pill against the comment, not the draft" do
      expect(outdated?("0f0e0d0c0b0a", action: :comment_post)).to be(false)
      expect(outdated?("a1b2c3d4e5f6", action: :comment_post)).to be(true)
    end

    # Sent before the tags existed: PublishDraft's own digest check still guards it.
    it "leaves an untagged pill alone" do
      expect(outdated?(nil)).to be(false)
    end

    # Published or discarded since: there is nothing to show again.
    context "when the draft is gone" do
      let(:draft_digest) { nil }

      it "leaves the tap to the assistant" do
        expect(outdated?("999999999999")).to be(false)
      end
    end
  end
end
