class Ai::Tools::WhatsappAiAssistant::SupportProposal < Ai::Tools::WhatsappAiAssistant::BaseTool
  description "Registers the citizen's support for the proposal this conversation is about, " \
              "and tells them the new count. Only call it when they have clearly said yes to " \
              "supporting — support cannot be withdrawn afterwards. The proposal is the one " \
              "the bot last asked about; if there is none, this answers with an error and you " \
              "should say you do not know which proposal they mean."

  def execute
    proposal_id = conversation.context["support_proposal_id"]

    return no_proposal_error if proposal_id.blank?

    ::Whatsapp::Flows::RegisterSupportService.call(
      conversation: conversation, proposal_id: proposal_id
    )

    halt("Registered the support and told the citizen the count.")
  end

  private

    def no_proposal_error
      { error: "This conversation is not about a specific proposal, so there is nothing to " \
               "support. Ask which proposal they mean." }
    end
end
