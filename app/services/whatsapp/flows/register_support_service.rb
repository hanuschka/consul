class Whatsapp::Flows::RegisterSupportService < Whatsapp::Flows::BaseService
  # Catalog D25 and D26. One tap commits — supporting is binary, cannot be
  # withdrawn, and asking a citizen to confirm a thing they already tapped once
  # is the kind of ceremony the catalog deliberately does not have.
  #
  # The proposal is re-resolved and re-checked here rather than trusted from the
  # pill: the id may have come from a card sent days ago, and by now the phase
  # can have closed or the proposal been retired.
  def initialize(conversation:, proposal_id:)
    super(conversation: conversation)
    @proposal_id = proposal_id
  end

  # Returns whether the support was actually registered. The three refusals
  # answer the citizen either way, but a caller that ends the conversation on
  # the strength of this — the duplicate offer does — must not do so when the
  # proposal turned out to be gone and the citizen still has a submission open.
  def call
    return refuse { send_gone } if proposal.blank?
    return refuse { send_already_supported } if proposal.voted_up_by?(user)
    return refuse { send_not_allowed } if !proposal.votable_by?(user)

    proposal.register_vote(user, "yes")

    send_thanks

    true
  end

  private

    # The message still goes out; only the answer to "was it registered" is
    # false. Written once so a fourth refusal cannot forget to return it.
    def refuse
      yield

      false
    end

    def user
      account.user
    end

    def proposal
      return @proposal if defined?(@proposal)

      @proposal = Proposal.not_retired.find_by(id: @proposal_id)
    end

    # Read back after the write rather than incremented in Ruby: the counter
    # cache is what the projekt page shows, and a number in the chat that
    # disagrees with the page is worse than no number at all.
    def send_thanks
      Whatsapp::Outbound.text(
        account: account,
        body: I18n.t("whatsapp.bot.support.thanks", count: proposal.reload.cached_votes_up)
      )
    end

    def send_already_supported
      Whatsapp::Outbound.text(account: account, body: I18n.t("whatsapp.bot.support.already"))
    end

    def send_not_allowed
      Whatsapp::Flows::RefuseParticipationService.call(
        conversation: @conversation,
        reason: :not_verified
      )
    end

    def send_gone
      Whatsapp::Outbound.text(account: account, body: I18n.t("whatsapp.bot.support.gone"))
    end
end
