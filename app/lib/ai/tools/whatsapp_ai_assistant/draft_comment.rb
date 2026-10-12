class Ai::Tools::WhatsappAiAssistant::DraftComment < Ai::Tools::WhatsappAiAssistant::BaseTool
  # The citizen's comment written down and nothing else. Posting is two more tools
  # away on purpose: this used to be one call that took the text and published it,
  # which meant the words that went under a citizen's name on a public page were
  # whichever words the model passed — and a model that read "ja" as the comment
  # put a citizen's name under the word "Ja".
  #
  # The refusals that used to guard the write guard the stash instead, so a comment
  # that could never be posted is refused before the citizen is asked to confirm
  # it: a closed comment thread or a retired proposal is not something to find out
  # about after they have said yes.
  description "Writes down the citizen's comment for one proposal, without posting it. Pass their " \
              "words exactly as they wrote them and the id find_contribution returned. Call it " \
              "only once they have actually written the comment: a message that merely agrees to " \
              "write one is not the comment, and asking them for it is start_comment. Nothing is " \
              "published and nothing is sent — show them what was written with " \
              "show_comment_for_confirmation, and post it with post_comment once they have said " \
              "yes. Calling this again replaces what is written down, which is how a correction " \
              "is made."

  parameters do
    integer :contribution_id,
      description: "Id of the proposal, exactly as find_contribution returned it"
    string :text, description: "The comment in the citizen's own words, as they wrote them"
  end

  def diagnostic_step
    ::Whatsapp::Conversation::Step::AWAITING_COMMENT
  end

  def execute(contribution_id:, text:)
    return not_linked_error("comment on a proposal") if user.blank?

    refusal = ::Whatsapp::Contributions::CreateCommentService.refusal(
      proposal: ::Proposal.find_by(id: contribution_id), user: user, body: text
    )

    return comment_refusal_error(refusal) if refusal.present?

    stash(contribution_id, text)
  end

  private

    # The digest is not written here, only the words. What the citizen has seen is a
    # separate question from what they have written, and writing both at once is how
    # a comment gets posted on a yes given to an earlier version of it.
    def stash(contribution_id, text)
      conversation.store_pending_comment!(proposal_id: contribution_id, text: text.to_s.strip)

      {
        written: true,
        hint: "Show it to them with show_comment_for_confirmation and ask whether it should go on " \
              "the page. Nothing is posted until they have answered that."
      }
    end
end
