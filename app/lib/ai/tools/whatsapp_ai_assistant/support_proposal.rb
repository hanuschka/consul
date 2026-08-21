class Ai::Tools::WhatsappAiAssistant::SupportProposal < Ai::Tools::WhatsappAiAssistant::BaseTool
  description "Registers the citizen's support for one proposal. Support cannot be withdrawn, so " \
              "it refuses unless the bot's previous message actually offered the support button " \
              "for this same proposal — show them the proposal with reply_with_actions carrying " \
              "support-<id>, and call this once they have tapped or clearly said yes to that one. " \
              "Pass the id find_contribution returned; never guess one. The proposal is " \
              "re-checked here, so a phase that has since closed or a proposal that has been " \
              "retired refuses rather than acting. On success the proposal, its new count and its " \
              "address are sent to them for you — do not write them out again."

  params do
    integer :contribution_id,
      description: "Id of the proposal, exactly as find_contribution returned it"
  end

  def execute(contribution_id:)
    return not_linked_error("support a proposal") if user.blank?

    refusal = refuse_without_confirmation(contribution_id)

    return refusal if refusal.present?

    outcome = ::Whatsapp::Contributions::RegisterSupportService.call(
      proposal_id: contribution_id, user: user
    )

    return refusal_for(outcome) if outcome.is_a?(Symbol)

    registered_answer(contribution_id, outcome)
  end

  private

    # The offer has to name this proposal, not merely be an offer. Whatsapp::Send
    # records an irreversible pill with its parameter for exactly this: a support
    # button shown for one proposal used to satisfy a call made with another, and the
    # citizen would have supported something they were never shown — which cannot be
    # undone from a chat.
    #
    # Read off the value held at inbound, so a tool cannot offer the pill and act on
    # it inside the same turn.
    def refuse_without_confirmation(contribution_id)
      offered = [:support, contribution_id].join(::Whatsapp::FlowActions::SEPARATOR)

      return if conversation.confirmation_offered?(offered)

      {
        error: "The bot's last message did not offer the support button for proposal " \
               "#{contribution_id}, so nothing was registered.",
        hint: "Show them that proposal — its title and its address — with a support-" \
              "#{contribution_id} button whose label says it supports, and call this again once " \
              "they have answered."
      }
    end

    # The block is composed from the proposal rather than described to the model, for
    # the same reason a published contribution is: the count in the chat has to be
    # the one the projekt page shows, and the proposal named has to be the one voted
    # on rather than the one the conversation was about a message ago.
    def registered_answer(contribution_id, supports)
      proposal = ::Proposal.find_by(id: contribution_id)

      send_recap(proposal: proposal, supports: supports)

      {
        supported: true,
        supports: supports,
        hint: "The proposal, its new count and its address have already been sent to them, so do " \
              "not repeat any of it. Say briefly that it is registered. Do not invite them to " \
              "support anything else."
      }
    end

    def send_recap(proposal:, supports:)
      block = ::Whatsapp::SupportRecap.block(
        account: account, proposal: proposal, supports: supports
      )

      return if block.blank?

      ::Whatsapp::MessageBlock.chunks(block).each do |part|
        ::Whatsapp::Send.text(account: account, body: part)
      end
    end

    def refusal_for(outcome)
      return gone_error if outcome == :gone
      return already_supported_answer if outcome == :already_supported
      return not_linked_error("support a proposal") if outcome == :not_linked

      {
        error: "This citizen may not support that proposal.",
        reason: outcome.to_s,
        rule: ::Whatsapp::ParticipationRules.explain(reason: outcome)
      }
    end

    def gone_error
      { error: "That proposal no longer has a public page — it may have been retired since it " \
               "was mentioned. Tell the citizen so; nothing was registered." }
    end

    def already_supported_answer
      {
        supported: false,
        already: true,
        hint: "They had already supported it. Say so plainly rather than as a failure."
      }
    end
end
