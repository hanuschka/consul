class Ai::Tools::WhatsappAiAssistant::CommentOnProposal < Ai::Tools::WhatsappAiAssistant::BaseTool
  description "Asks the citizen to write a comment on the proposal this conversation is " \
              "about. Call it when they say they want to add something, reply to, or comment " \
              "on a proposal. Their next message is then taken as the comment itself, so do " \
              "not call this if they have already written the comment — hand that to the flow."

  def execute
    proposal_id = conversation.context["support_proposal_id"] ||
                  conversation.context["comment_proposal_id"]
    proposal = ::Proposal.find_by(id: proposal_id)

    return no_proposal_error("comment on") if proposal.blank?

    ::Whatsapp::Flows::CommentPromptService.call(conversation: conversation, proposal: proposal)

    halt("Asked the citizen for their comment.")
  end
end
