require "rails_helper"

describe Whatsapp::Conversation do
  # One reset for the pill and for the typed request alike. What it clears depends
  # on whether the citizen has written something a reset would lose.
  describe "#begin_start_over!" do
    let(:context) { {} }

    let(:conversation) { Whatsapp::Conversation.new(context: context, projekt_phase_id: 1) }

    let(:written_comment) { { "proposal_id" => 7, "text" => "Gute Idee" } }

    before do
      allow(conversation).to receive(:update!) do |attributes|
        conversation.assign_attributes(attributes)
      end
    end

    # The bug: the invitation went, but the proposal it named stayed behind, so
    # the next reply still knew which proposal the comment had been meant for.
    context "when a comment was asked for and nothing is written yet" do
      let(:context) { { "opened_steps" => ["comment"], "comment_proposal_id" => 7 } }

      it "drops the invitation" do
        conversation.begin_start_over!

        expect(conversation.opened_steps).to be_empty
      end

      it "forgets the proposal the comment was meant for" do
        conversation.begin_start_over!

        expect(conversation.comment_proposal_id).to be_nil
      end

      it "starts over without asking" do
        conversation.begin_start_over!

        expect(conversation.start_over_requested?).to be(false)
      end

      it "leaves the projekt" do
        conversation.begin_start_over!

        expect(conversation.projekt_phase_id).to be_nil
      end
    end

    context "when other invitations are open" do
      let(:context) { { "opened_steps" => ["contribution", "comment"] } }

      it "drops all of them" do
        conversation.begin_start_over!

        expect(conversation.opened_steps).to be_empty
      end
    end

    context "when a comment is written and not posted" do
      let(:context) do
        {
          "opened_steps" => ["comment"],
          "comment_proposal_id" => 7,
          "pending_comment" => written_comment
        }
      end

      it "keeps the comment" do
        conversation.begin_start_over!

        expect(conversation.pending_comment).to eq(written_comment)
      end

      it "asks before discarding it" do
        conversation.begin_start_over!

        expect(conversation.start_over_requested?).to be(true)
      end

      it "keeps the projekt until they answer" do
        conversation.begin_start_over!

        expect(conversation.projekt_phase_id).to eq(1)
      end

      it "keeps the proposal the comment is for" do
        conversation.begin_start_over!

        expect(conversation.comment_proposal_id).to eq(7)
      end

      it "discards the comment once they say so" do
        conversation.begin_start_over!
        conversation.discard_draft!

        expect(conversation.pending_comment).to be_nil
      end

      # Posting keeps the context, so the request has to go with the comment, or a
      # later abandonment would be answered with a fresh start nobody asked for.
      it "lets the request go once the comment is posted instead" do
        conversation.begin_start_over!
        conversation.clear_pending_comment!

        expect(conversation.start_over_requested?).to be(false)
      end
    end

    context "when a contribution and a comment are both unsaved" do
      let(:context) do
        { "draft_data" => { "title" => "Mehr Bäume" }, "pending_comment" => written_comment }
      end

      it "asks before discarding either" do
        conversation.begin_start_over!

        expect(conversation.start_over_requested?).to be(true)
      end

      it "keeps the request for the draft once the comment is posted" do
        conversation.begin_start_over!
        conversation.clear_pending_comment!

        expect(conversation.start_over_requested?).to be(true)
      end

      it "discards both once they say so" do
        conversation.begin_start_over!
        conversation.discard_draft!

        expect(conversation.unsaved_work?).to be(false)
      end
    end
  end
end
