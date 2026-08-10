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

  def call
    return send_gone if proposal.blank?
    return send_already_supported if proposal.voted_up_by?(user)
    return send_not_allowed if !proposal.votable_by?(user)

    proposal.register_vote(user, "yes")

    send_thanks
  end

  private

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
