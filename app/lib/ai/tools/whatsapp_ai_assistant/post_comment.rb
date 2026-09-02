class Ai::Tools::WhatsappAiAssistant::PostComment < Ai::Tools::WhatsappAiAssistant::BaseTool
  # Posts what draft_comment wrote down, and takes nothing: the words come from the
  # stash rather than from the model, which is the whole point of splitting the old
  # single call into three. A tool that accepted the text here could post something
  # other than what show_comment_for_confirmation put in front of the citizen, and
  # a comment under someone's name on a public page is not undoable from a chat.
  description "Posts the comment that was written down and shown to the citizen, under their own " \
              "name on a public page. It takes nothing — the words are the ones they confirmed. " \
              "Call it only once they have clearly said that comment should go on the page. It " \
              "refuses when nothing has been written down, when the bot's previous message did " \
              "not offer the comment_post button, and when the words have changed since they were " \
              "shown; each refusal says what would resolve it. On success the comment and its " \
              "address, or the sentence that it is waiting to be looked at, are sent to them for " \
              "you — so do not write either out again."

  def diagnostic_step
    ::Whatsapp::Conversation::Step::IDLE
  end

  def execute
    return not_linked_error("comment on a proposal") if user.blank?
    return nothing_written_error if pending["text"].blank?

    refusal = precondition_refusal

    return refusal if refusal.present?

    post
  end

  private

    def pending
      conversation.pending_comment.to_h
    end

    def precondition_refusal
      refuse_without_confirmation || refuse_on_stale_preview
    end

    # Read off the value held at inbound, so a tool cannot offer the pill and act on
    # it inside the same turn — the same guarantee publishing a contribution makes.
    def refuse_without_confirmation
      return if conversation.confirmation_offered?(:comment_post)

      {
        error: "The citizen has not been shown this comment and asked whether it should go on the " \
               "page, so nothing was posted.",
        hint: "Show it to them with show_comment_for_confirmation, offering a button whose label " \
              "says it posts. Call this again once they have answered that question."
      }
    end

    # The half the pill cannot answer: the button is offered against a message, and
    # draft_comment can rewrite the words after it without the offer going anywhere.
    # So consent is held against the words rather than against the message.
    def refuse_on_stale_preview
      shown = conversation.comment_preview_digest

      return if shown.present? && shown == ::Whatsapp::CommentPreview.digest(conversation: conversation)

      {
        error: "The comment has changed since the citizen was last shown it, so their yes was " \
               "given to different words and nothing was posted.",
        hint: "Call show_comment_for_confirmation so they see what is written down now, and call " \
              "this again once they have answered."
      }
    end

    def post
      outcome = ::Whatsapp::Contributions::CreateCommentService.call(
        proposal: ::Proposal.find_by(id: pending["proposal_id"]),
        user: user,
        body: pending["text"]
      )

      return refusal_for(outcome) if outcome.is_a?(Symbol)

      posted_answer(outcome)
    end

    # Which of the two the citizen is told is decided by the row that was just
    # written, not by a setting: this portal publishes comments immediately and hides
    # them afterwards, so telling everyone their comment is "being reviewed" would be
    # false — but where a moderation rule does hide it on creation, that is the true
    # answer, so the row is asked.
    #
    # The block is sent before the stash is cleared, because the renderer reads the
    # words out of it.
    def posted_answer(comment)
      url = ::Whatsapp::PublishedResourceUrl.call(comment)

      send_recap(url: url)

      conversation.clear_pending_comment!

      {
        posted: true,
        visible: !comment.hidden?,
        url: url,
        hint: comment.hidden? ? PENDING_HINT : PUBLISHED_HINT
      }.compact
    end

    def send_recap(url:)
      block =
        if url.present?
          ::Whatsapp::CommentPreview.posted_block(conversation: conversation, url: url)
        else
          ::Whatsapp::CommentPreview.awaiting_review_block(conversation: conversation)
        end

      return if block.blank?

      ::Whatsapp::MessageBlock.chunks(block).each do |part|
        ::Whatsapp::Send.text(account: account, body: part)
      end
    end

    PENDING_HINT = "It is in but waiting to be looked at before it appears. The comment and that " \
                   "sentence have already been sent to them, so do not repeat either and do not " \
                   "offer a link.".freeze

    PUBLISHED_HINT = "The comment and its address have already been sent to them, so do not " \
                     "repeat either and do not write a link. Say briefly that it is on the page " \
                     "now.".freeze

    def nothing_written_error
      { error: "No comment has been written down in this conversation, so there is nothing to " \
               "post. Ask the citizen what they want to say and call draft_comment with their " \
               "own words." }
    end

    def refusal_for(outcome)
      return gone_error if outcome == :gone
      return already_posted_answer if outcome == :duplicate
      return closed_error if outcome == :closed
      return blank_error if outcome == :blank
      return confirmation_only_error if outcome == :confirmation_only
      return not_linked_error("comment on a proposal") if outcome == :not_linked

      invalid_error
    end

    # Cleared with the refusal: the proposal is gone, so the words have nowhere left
    # to go and leaving them stashed would have the next turn offer to post them
    # again.
    def gone_error
      conversation.clear_pending_comment!

      { error: "That proposal is not there any more, so there is nothing to comment on. Tell the " \
               "citizen so; nothing was posted." }
    end

    # The stash is cleared like after a post: the words are on the page already, and
    # leaving them would have the next turn offer to post them once more.
    def already_posted_answer
      conversation.clear_pending_comment!

      {
        posted: false,
        already: true,
        hint: "This exact comment is already on the page under their name. Say so plainly " \
              "rather than as a failure, and do not post it again."
      }
    end

    def closed_error
      { error: "Comments are not open on that proposal any more. Tell the citizen plainly; " \
               "nothing was posted." }
    end

    def blank_error
      { error: "There was no comment text. Ask the citizen what they want to say and call " \
               "draft_comment with it." }
    end

    def confirmation_only_error
      { error: "What was written down is a yes or a no rather than a comment, so nothing was " \
               "posted. Ask them for what they actually want to say on the page." }
    end

    def invalid_error
      { error: "The portal refused the comment. Tell the citizen it could not be posted and ask " \
               "them to put it differently, then call draft_comment with the new words." }
    end
end
