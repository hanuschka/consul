class Ai::Tools::WhatsappAiAssistant::CommentOnProposal <
  Ai::Tools::WhatsappAiAssistant::BaseTool
  description "Posts the citizen's comment on one proposal, under their own name, on a public " \
              "page. Pass their words as they wrote them and the id find_contribution returned. " \
              "Call it only once they have actually written the comment: a message that merely " \
              "agrees to write one is not the comment, and posting \"ja\" under someone's name " \
              "is not something this chat can undo. One call publishes it — a comment is short " \
              "enough that showing it back for confirmation would cost more taps than writing it " \
              "did. Say afterwards whether it is visible or waiting to be reviewed."

  params do
    integer :contribution_id,
      description: "Id of the proposal, exactly as find_contribution returned it"
    string :text, description: "The comment in the citizen's own words, as they wrote it"
  end

  def diagnostic_step
    ::Whatsapp::Conversation::Step::AWAITING_COMMENT
  end

  def execute(contribution_id:, text:)
    return not_linked_error("comment on a proposal") if user.blank?

    proposal = ::Proposal.find_by(id: contribution_id)
    outcome = ::Whatsapp::Contributions::CreateCommentService.call(
      proposal: proposal, user: user, body: text
    )

    return refusal_for(outcome) if outcome.is_a?(Symbol)

    posted_answer(outcome)
  end

  private

    # Which of the two the citizen is told is decided by the row that was just
    # written, not by a setting: this portal publishes comments immediately and hides
    # them afterwards, so telling everyone their comment is "being reviewed" would be
    # false — but where a moderation rule does hide it on creation, that is the true
    # answer, so the row is asked.
    def posted_answer(comment)
      {
        posted: true,
        visible: !comment.hidden?,
        hint: comment.hidden? ? PENDING_HINT : PUBLISHED_HINT
      }
    end

    PENDING_HINT = "Say it is in but waiting to be looked at before it appears.".freeze

    PUBLISHED_HINT = "Say it is on the page now.".freeze

    def refusal_for(outcome)
      return gone_error if outcome == :gone
      return closed_error if outcome == :closed
      return blank_error if outcome == :blank
      return confirmation_only_error if outcome == :confirmation_only
      return not_linked_error("comment on a proposal") if outcome == :not_linked

      invalid_error
    end

    def gone_error
      { error: "That proposal is not there any more, so there is nothing to comment on. Tell the " \
               "citizen so; nothing was posted." }
    end

    def closed_error
      { error: "Comments are not open on that proposal. Tell the citizen plainly; nothing was " \
               "posted." }
    end

    def blank_error
      { error: "There was no comment text. Ask the citizen what they want to say." }
    end

    # Refused rather than published. A single word of agreement is the citizen
    # answering a question, not their contribution to a public page, and their name
    # would be under it.
    def confirmation_only_error
      { error: "That is a yes or a no rather than a comment, so nothing was posted. Ask them for " \
               "what they actually want to say on the page." }
    end

    def invalid_error
      { error: "The portal refused the comment. Tell the citizen it could not be posted and ask " \
               "them to put it differently." }
    end
end
