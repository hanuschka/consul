class Ai::Tools::WhatsappAiAssistant::StartComment < Ai::Tools::WhatsappAiAssistant::BaseTool
  # The moment between asking the citizen for a comment and getting it, which
  # nothing else records: the words are not there yet, so there is no pending
  # comment, and the proposal find_contribution remembers is only the one last
  # talked about. A "Stopp" answering the invitation is most likely about the
  # comment, and with nothing recorded it was read as leaving the channel.
  description "Records that you are asking the citizen to write a comment on one proposal. Call " \
              "it once they have said they want to comment and before you ask them for the " \
              "comment, with the id find_contribution returned. It writes nothing on the page " \
              "and sends nothing — ask them for their comment in your own words afterwards. " \
              "When their message already holds the comment itself, call draft_comment instead."

  parameters do
    integer :contribution_id,
      description: "Id of the proposal, exactly as find_contribution returned it"
  end

  def diagnostic_step
    ::Whatsapp::Conversation::Step::AWAITING_COMMENT
  end

  def execute(contribution_id:)
    refusal = ::Whatsapp::Contributions::CreateCommentService.thread_refusal(
      proposal: ::Proposal.find_by(id: contribution_id), user: user
    )

    return comment_refusal_error(refusal) if refusal.present?

    conversation.store_comment_proposal_id!(contribution_id)
    conversation.open_step!("comment")

    {
      started: true,
      next_step: "Ask the citizen to write their comment here, then call draft_comment with " \
                 "their own words."
    }
  end
end
