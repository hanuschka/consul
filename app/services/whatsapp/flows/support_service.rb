class Whatsapp::Flows::SupportService < Whatsapp::Flows::BaseService
  # Catalog D24-D26 — the support question and the tap that commits it. One
  # service because the prompt writes the context key whose id the register
  # half re-resolves.

  # D24. The proposal id is written into the conversation as well as into the
  # pill, because the citizen may answer in words rather than tapping — "yes"
  # has to reach the same proposal the pill would have.
  def self.prompt(conversation:, proposal:)
    new(conversation: conversation).prompt(proposal)
  end

  # D25 and D26. One tap commits — supporting is binary, cannot be withdrawn,
  # and asking a citizen to confirm a thing they already tapped once is the
  # kind of ceremony the catalog deliberately does not have.
  #
  # The proposal is re-resolved and re-checked here rather than trusted from
  # the pill: the id may have come from a card sent days ago, and by now the
  # phase can have closed or the proposal been retired.
  def self.register(conversation:, proposal_id:)
    new(conversation: conversation).register(proposal_id)
  end

  def prompt(proposal)
    @conversation.merge_context!(support_proposal_id: proposal.id)

    Whatsapp::Send.buttons(
      account: account,
      body: Whatsapp.phrase("whatsapp.bot.support.prompt", title: proposal.title),
      buttons: prompt_buttons(proposal)
    )
  end

  # Returns whether the support was actually registered. The three refusals
  # answer the citizen either way, but a caller that ends the conversation on
  # the strength of this — the duplicate offer does — must not do so when the
  # proposal turned out to be gone and the citizen still has a submission
  # open.
  def register(proposal_id)
    @proposal_id = proposal_id

    return send_gone.then { false } if proposal.blank?
    return send_already_supported.then { false } if proposal.voted_up_by?(user)
    return send_not_allowed.then { false } if !proposal.votable_by?(user)

    proposal.register_vote(user, "yes")

    send_thanks.then { true }
  end

  private

    def user
      account.user
    end

    def proposal
      return @proposal if defined?(@proposal)

      @proposal = Proposal.not_retired.find_by(id: @proposal_id)
    end

    def prompt_buttons(proposal)
      [
        Whatsapp::FlowActions.button(
          action: :support, label_key: "whatsapp.bot.buttons.support", param: proposal.id
        ),
        Whatsapp::FlowActions.button(
          action: :dismiss, label_key: "whatsapp.bot.buttons.no_thanks"
        )
      ]
    end

    # Read back after the write rather than incremented in Ruby: the counter
    # cache is what the projekt page shows, and a number in the chat that
    # disagrees with the page is worse than no number at all.
    def send_thanks
      Whatsapp::Send.text(
        account: account,
        body: Whatsapp.phrase("whatsapp.bot.support.thanks", count: proposal.reload.cached_votes_up)
      )
    end

    def send_already_supported
      Whatsapp::Send.text(
        account: account,
        body: Whatsapp.phrase("whatsapp.bot.support.already")
      )
    end

    def send_not_allowed
      Whatsapp::Flows::RefuseParticipationService.call(
        conversation: @conversation,
        reason: :not_verified
      )
    end

    def send_gone
      Whatsapp::Send.text(
        account: account,
        body: Whatsapp.phrase("whatsapp.bot.support.gone")
      )
    end
end
