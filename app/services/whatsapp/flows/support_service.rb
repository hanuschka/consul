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
    @conversation.store_support_proposal_id!(proposal.id)

    Whatsapp::Send.buttons(
      account: account,
      body: prompt_body(proposal),
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

    # The link so the citizen can read the proposal before backing it: support
    # cannot be withdrawn, and a title alone is thin ground for a decision that
    # final. The link-less wording covers a proposal reached from a card sent
    # days ago whose page has since gone.
    def prompt_body(proposal)
      url = Whatsapp::PublishedResourceUrl.call(proposal)

      if url.blank?
        return Whatsapp.phrase("whatsapp.bot.support.prompt_without_url", title: proposal.title)
      end

      Whatsapp.phrase("whatsapp.bot.support.prompt", title: proposal.title, url: url)
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
      count = proposal.reload.cached_votes_up
      url = Whatsapp::PublishedResourceUrl.call(proposal)

      if url.blank?
        return Whatsapp::Send.text(
          account: account,
          body: Whatsapp.phrase("whatsapp.bot.support.thanks_without_url", count: count)
        )
      end

      Whatsapp::Send.text(
        account: account,
        body: Whatsapp.phrase("whatsapp.bot.support.thanks", count: count, url: url)
      )
    end

    def send_already_supported
      Whatsapp::Send.text(
        account: account,
        body: Whatsapp.phrase("whatsapp.bot.support.already")
      )
    end

    def projekt_phase
      @projekt_phase ||= proposal.projekt_phase
    end

    # Why the phase said no, in its own vocabulary — the same symbols
    # RefuseParticipationService writes copy for. Read off the phase rather
    # than assumed: hardcoded :not_verified, someone refused because the phase
    # had closed or because they live outside the eligible area was told their
    # account needed verifying and handed a link that would not have unblocked
    # them.
    #
    # Costs nothing extra to ask a second time — Proposal#votable_by? delegates
    # to this same phase, and ProjektPhase#permission_problem memoizes per user
    # and location, so the refusal reads back the verdict that refused it.
    def refusal_reason
      projekt_phase&.permission_problem(user, location: :votes_component) || :not_verified
    end

    # Sent as plain text rather than through RefuseParticipationService#call:
    # that one resets the flow, and being refused a support must not cost the
    # citizen a submission they had open at the time. The lead-in says
    # supporting, because that is what was refused — the shared copy under it
    # states the rule, which is the same rule either way.
    def send_not_allowed
      Whatsapp::Send.text(
        account: account,
        body: [
          Whatsapp.phrase("whatsapp.bot.support.refused_intro"),
          Whatsapp::Flows::RefuseParticipationService.explanation_for(
            reason: refusal_reason, projekt_phase: projekt_phase
          )
        ].compact_blank.join("\n\n")
      )
    end

    def send_gone
      Whatsapp::Send.text(
        account: account,
        body: Whatsapp.phrase("whatsapp.bot.support.gone")
      )
    end
end
