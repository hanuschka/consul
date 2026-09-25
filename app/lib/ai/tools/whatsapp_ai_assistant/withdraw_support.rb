class Ai::Tools::WhatsappAiAssistant::WithdrawSupport < Ai::Tools::WhatsappAiAssistant::BaseTool
  # The way back, and the sibling of SupportProposal rather than a mode of it: the
  # call site says which direction it goes, and each owns the one refusal the other
  # has no use for.
  #
  # Like its sibling it exists for the citizen who asked in words. A tap on the
  # support button of something they already support has already taken it back by
  # the time the assistant is asked anything.
  description "Takes back the citizen's support for one proposal, lowering its count. Call it " \
              "when they have asked for that in words; a tap on a support button already did it " \
              "before you are asked, so never call this for one. Pass the id find_contribution " \
              "returned; never guess one. A proposal they do not support refuses rather than " \
              "acting. On success the proposal, the count as it now stands and its address are " \
              "sent to them for you — do not write them out again."

  params do
    integer :contribution_id,
      description: "Id of the proposal, exactly as find_contribution returned it"
  end

  def execute(contribution_id:)
    return not_linked_error("take back a support") if user.blank?

    outcome = ::Whatsapp::Contributions::WithdrawSupportService.call(
      proposal_id: contribution_id, user: user
    )

    return refusal_for(outcome) if outcome.is_a?(Symbol)

    withdrawn_answer(contribution_id, outcome)
  end

  private

    def withdrawn_answer(contribution_id, supports)
      proposal = ::Proposal.find_by(id: contribution_id)

      send_recap(proposal: proposal, supports: supports)

      {
        withdrawn: true,
        supports: supports,
        hint: "The proposal, the count as it now stands and its address have already been sent " \
              "to them, so do not repeat any of it. Say briefly that it is withdrawn. Do not " \
              "ask why and do not talk them back into it."
      }
    end

    def send_recap(proposal:, supports:)
      ::Whatsapp::Send.message_block(
        account: account,
        block: ::Whatsapp::SupportRecap.withdrawn_block(
          account: account, proposal: proposal, supports: supports
        )
      )
    end

    def refusal_for(outcome)
      return gone_error if outcome == :gone
      return not_supported_answer if outcome == :not_supported
      return not_withdrawn_error if outcome == :not_withdrawn
      return not_linked_error("take back a support") if outcome == :not_linked

      {
        error: "That support could not be taken back.",
        reason: outcome.to_s
      }
    end

    def not_withdrawn_error
      { error: "The support is still there and the count is unchanged. Tell the citizen it could " \
               "not be taken back and that they can try again; do not say it worked." }
    end

    def gone_error
      { error: "That proposal no longer has a public page — it may have been retired since it " \
               "was mentioned. Tell the citizen so; nothing was changed." }
    end

    def not_supported_answer
      {
        withdrawn: false,
        hint: "They do not support that proposal, so there was nothing to take back. Say so " \
              "plainly rather than as a failure."
      }
    end
end
