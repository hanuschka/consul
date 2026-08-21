require "rails_helper"

describe Ai::Tools::WhatsappAiAssistant::PostComment do
  # The two guarantees the old single-call comment tool made neither of: the
  # citizen has seen these exact words, and the words have not changed since.
  subject(:tool) { Ai::Tools::WhatsappAiAssistant::PostComment.new(conversation: conversation) }

  let(:user) { double(:user) }
  let(:account) { double(:account, user: user) }
  let(:pending) { { "proposal_id" => 482, "text" => "Genau hier fehlt eine Bank." } }

  let(:conversation) do
    double(
      :conversation,
      whatsapp_account: account,
      pending_comment: pending,
      comment_preview_digest: nil
    )
  end

  before do
    allow(Whatsapp::CommentPreview).to receive(:digest).and_return("current-digest")
    allow(conversation).to receive(:confirmation_offered?).and_return(false)
  end

  describe "the confirmation gate" do
    it "refuses when no post button was offered on an earlier message" do
      answer = tool.execute

      expect(answer[:error]).to match(/has not been shown this comment/)
      expect(answer[:hint]).to match(/show_comment_for_confirmation/)
    end

    it "writes nothing when it refuses" do
      expect(Whatsapp::Contributions::CreateCommentService).not_to receive(:call)

      tool.execute
    end
  end

  describe "the stale-preview gate" do
    before { allow(conversation).to receive(:confirmation_offered?).and_return(true) }

    it "refuses when nothing has been shown to the citizen at all" do
      expect(tool.execute[:error]).to match(/has changed since the citizen was last shown it/)
    end

    # The correction case: draft_comment rewrites the words and the offered pill
    # survives on the record, so only the digest separates a yes to these words
    # from a yes to the ones before them.
    it "refuses when the words have changed since they were shown" do
      allow(conversation).to receive(:comment_preview_digest).and_return("digest-of-old-words")

      expect(tool.execute[:error]).to match(/has changed since the citizen was last shown it/)
    end

    it "writes nothing when it refuses" do
      allow(conversation).to receive(:comment_preview_digest).and_return("digest-of-old-words")

      expect(Whatsapp::Contributions::CreateCommentService).not_to receive(:call)

      tool.execute
    end
  end

  describe "with nothing written down" do
    before { allow(conversation).to receive(:pending_comment).and_return(nil) }

    it "sends the model back to draft_comment rather than to a gate" do
      expect(tool.execute[:error]).to match(/No comment has been written down/)
    end
  end

  describe "once the citizen has confirmed the words as they stand" do
    let(:comment) { instance_double(Comment, hidden?: false) }

    before do
      allow(conversation).to receive(:confirmation_offered?).and_return(true)
      allow(conversation).to receive(:comment_preview_digest).and_return("current-digest")
      allow(conversation).to receive(:clear_pending_comment!)

      allow(Proposal).to receive(:find_by).and_return(double(:proposal))
      allow(Whatsapp::Contributions::CreateCommentService).to receive(:call).and_return(comment)
      allow(Whatsapp::PublishedResourceUrl).to receive(:call).and_return("https://example.org/p/1#comment_9")
      allow(Whatsapp::CommentPreview).to receive(:posted_block).and_return("the comment")
      allow(Whatsapp::MessageBlock).to receive(:chunks).and_return(["the comment"])
      allow(Whatsapp::Send).to receive(:text)
    end

    it "posts the stashed words, not anything the model passed" do
      expect(Whatsapp::Contributions::CreateCommentService)
        .to receive(:call)
        .with(hash_including(body: "Genau hier fehlt eine Bank."))
        .and_return(comment)

      tool.execute
    end

    it "sends the comment back composed from the stash" do
      expect(Whatsapp::Send).to receive(:text).with(account: account, body: "the comment")

      tool.execute
    end

    it "sends the recap before the stash is cleared" do
      expect(Whatsapp::CommentPreview).to receive(:posted_block).ordered
      expect(conversation).to receive(:clear_pending_comment!).ordered

      tool.execute
    end

    context "when a moderation rule hid the comment on creation" do
      let(:comment) { instance_double(Comment, hidden?: true) }

      before do
        allow(Whatsapp::PublishedResourceUrl).to receive(:call).and_return(nil)
        allow(Whatsapp::CommentPreview).to receive(:awaiting_review_block).and_return("held")
      end

      it "offers no address" do
        expect(tool.execute[:url]).to be_nil
      end

      it "says plainly that it is waiting rather than sending the posted block" do
        expect(Whatsapp::CommentPreview).to receive(:awaiting_review_block)
        expect(Whatsapp::CommentPreview).not_to receive(:posted_block)

        tool.execute
      end
    end
  end
end
