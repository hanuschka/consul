class Ai::Tools::WhatsappAiAssistant::SupportProposal < Ai::Tools::WhatsappAiAssistant::BaseTool
  description "Registers the citizen's support for the proposal this conversation is about, " \
              "and tells them the new count. Only call it when they have clearly said yes to " \
              "supporting — support cannot be withdrawn afterwards. The proposal is the one " \
              "the bot last asked about; if there is none, this answers with an error and you " \
              "should say you do not know which proposal they mean."

  def execute
    proposal_id = conversation.context["support_proposal_id"]

    return no_proposal_error("support") if proposal_id.blank?

    ::Whatsapp::Flows::SupportService.register(
      conversation: conversation, proposal_id: proposal_id
    )

    halt("Registered the support and told the citizen the count.")
  end
end
