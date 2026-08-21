require "rails_helper"

describe Whatsapp::CommentPreview do
  let(:account) { double(:account) }
  let(:text) { "Genau an dieser Ecke fehlt seit Jahren eine Bank." }
  let(:pending) { { "proposal_id" => 482, "text" => text } }
  let(:conversation) { double(:conversation, pending_comment: pending, whatsapp_account: account) }

  before do
    allow(Whatsapp::AiAssistant::BotCopyService)
      .to receive(:call) { |account:, lines:| lines }
    allow(Proposal).to receive(:find_by).with(id: 482).and_return(double(:proposal, title: "Mehr Bänke"))
  end

  describe ".confirmation_block" do
    it "carries the citizen's words exactly as they wrote them" do
      expect(Whatsapp::CommentPreview.confirmation_block(conversation: conversation)).to include(text)
    end

    it "names the proposal it goes on" do
      expect(Whatsapp::CommentPreview.confirmation_block(conversation: conversation))
        .to include("Mehr Bänke")
    end

    it "offers no address, because there is nothing to open yet" do
      expect(Whatsapp::CommentPreview.confirmation_block(conversation: conversation))
        .not_to include("http")
    end

    it "is nil when nothing has been written down" do
      allow(conversation).to receive(:pending_comment).and_return(nil)

      expect(Whatsapp::CommentPreview.confirmation_block(conversation: conversation)).to be_nil
    end
  end

  describe ".posted_block" do
    it "repeats the words and writes the address out" do
      block = Whatsapp::CommentPreview.posted_block(
        conversation: conversation, url: "https://example.org/proposals/1#comment_9"
      )

      expect(block).to include(text)
      expect(block).to include("https://example.org/proposals/1#comment_9")
    end
  end

  describe ".awaiting_review_block" do
    it "repeats the words and offers no address at all" do
      block = Whatsapp::CommentPreview.awaiting_review_block(conversation: conversation)

      expect(block).to include(text)
      expect(block).not_to include("http")
    end
  end

  describe ".digest" do
    it "is stable for unchanged words" do
      expect(Whatsapp::CommentPreview.digest(conversation: conversation))
        .to eq(Whatsapp::CommentPreview.digest(conversation: conversation))
    end

    it "changes when the words change" do
      before_correction = Whatsapp::CommentPreview.digest(conversation: conversation)

      allow(conversation)
        .to receive(:pending_comment)
        .and_return(pending.merge("text" => "Anders formuliert."))

      expect(Whatsapp::CommentPreview.digest(conversation: conversation))
        .not_to eq(before_correction)
    end

    # A comment confirmed for one proposal must not be postable under another.
    it "changes when the proposal changes" do
      before_switch = Whatsapp::CommentPreview.digest(conversation: conversation)

      allow(conversation)
        .to receive(:pending_comment)
        .and_return(pending.merge("proposal_id" => 99))

      expect(Whatsapp::CommentPreview.digest(conversation: conversation)).not_to eq(before_switch)
    end

    it "is nil when nothing has been written down" do
      allow(conversation).to receive(:pending_comment).and_return({})

      expect(Whatsapp::CommentPreview.digest(conversation: conversation)).to be_nil
    end
  end
end
