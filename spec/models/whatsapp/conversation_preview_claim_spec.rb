require "rails_helper"

describe Whatsapp::Conversation do
  # One change, one preview: a second preview of the same version under the same
  # citizen message is a second set of pills for one question.
  describe "#claim_preview!" do
    let(:conversation) { Whatsapp::Conversation.new(context: {}) }

    before do
      allow(conversation).to receive(:update!) do |attributes|
        conversation.assign_attributes(attributes)
      end
    end

    def claim(kind: :draft, digest: "digest-1")
      conversation.claim_preview!(kind: kind, digest: digest)
    end

    context "while a citizen message is being answered" do
      before { conversation.hold_inbound_message_id!("wamid.ONE") }

      it "lets the first preview of a version out" do
        expect(claim).to be(true)
      end

      it "holds back the same version a second time" do
        claim

        expect(claim).to be(false)
      end

      it "lets a changed version out under the same message" do
        claim

        expect(claim(digest: "digest-2")).to be(true)
      end

      it "keeps a draft's preview and a comment's apart" do
        claim

        expect(claim(kind: :comment)).to be(true)
      end

      it "lets the same version out again under the next message" do
        claim
        conversation.hold_inbound_message_id!("wamid.TWO")

        expect(claim).to be(true)
      end

      it "writes nothing when it holds a preview back" do
        claim

        expect(conversation).not_to receive(:update!)

        claim
      end
    end

    context "when no citizen message is held" do
      it "lets every preview out" do
        claim

        expect(claim).to be(true)
      end
    end
  end
end
