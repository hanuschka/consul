class Ai::Tools::WhatsappAiAssistant::SupportProposal < Ai::Tools::WhatsappAiAssistant::BaseTool
  # The way a support goes in when the citizen asked for one in words. A tap does not
  # come through here at all: the inbound side registers that itself, because the id
  # on a tapped button is one the citizen was looking at and needs nothing checked
  # about it.
  #
  # What that leaves this tool is the case with no button behind it — "das unterstütze
  # ich" about a contribution found a message ago — which is why the id still has to
  # be one find_contribution returned rather than one the model liked the look of.
  description "Registers the citizen's support for one proposal, which they can take back " \
              "again afterwards. Call it when they have asked for it in words; a tap on a " \
              "support button is already registered before you are asked, so never call this " \
              "for one. Pass the id find_contribution returned; never guess one. The proposal " \
              "is re-checked here, so a phase that has since closed or a proposal that has " \
              "been retired refuses rather than acting. On success the proposal, its new count " \
              "and its address are sent to them for you — do not write them out again."

  params do
    integer :contribution_id,
      description: "Id of the proposal, exactly as find_contribution returned it"
  end

  def execute(contribution_id:)
    return not_linked_error("support a proposal") if user.blank?

    outcome = ::Whatsapp::Contributions::RegisterSupportService.call(
      proposal_id: contribution_id, user: user
    )

    return refusal_for(outcome) if outcome.is_a?(Symbol)

    registered_answer(contribution_id, outcome)
  end

  private

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
              "not repeat any of it. Say briefly that it is registered, and offer no reassurance " \
              "about it being final — it is not. Do not invite them to support anything else."
      }
    end

    def send_recap(proposal:, supports:)
      ::Whatsapp::Send.message_block(
        account: account,
        block: ::Whatsapp::SupportRecap.registered_block(
          account: account, proposal: proposal, supports: supports
        )
      )
    end

    def refusal_for(outcome)
      return gone_error if outcome == :gone
      return already_supported_answer if outcome == :already_supported
      return not_registered_error if outcome == :not_registered
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

    # The refusal with no rule behind it: the phase allowed the support and the write
    # still did not take. Nothing to explain, so nothing is invented — say it failed
    # and let them try again rather than confirming something that did not happen.
    def not_registered_error
      { error: "The support did not go through, and the count is unchanged. Tell the citizen it " \
               "could not be registered and that they can try again; do not say it worked." }
    end

    def already_supported_answer
      {
        supported: false,
        already: true,
        hint: "They had already supported it. Say so plainly rather than as a failure, and offer " \
              "them the way back: withdraw_support takes it back again."
      }
    end
end
