class Whatsapp::Contributions::RegisterSupportService < ApplicationService
  # Registers a citizen's support for one proposal. The proposal is resolved and
  # re-checked here rather than trusted from whoever asked: the id can come from a
  # pill sent days ago, and by now the phase can have closed or the proposal been
  # retired.
  #
  # Support cannot be withdrawn, which is why the refusals are as carefully
  # separated as they are — "already supported" and "not allowed to" are two
  # different things to be told, and neither is "done".
  #
  # Returns the new support count, or a symbol naming what stopped it. The caller
  # turns that into words.
  def initialize(proposal_id:, user:)
    @proposal_id = proposal_id
    @user = user
  end

  def call
    return :not_linked if @user.blank?
    return :gone if proposal.blank?
    return :already_supported if proposal.voted_up_by?(@user)
    return refusal if !proposal.votable_by?(@user)

    proposal.register_vote(@user, "yes")

    # Read back after the write rather than incremented in Ruby: the counter cache
    # is what the projekt page shows, and a number in the chat that disagrees with
    # the page is worse than no number at all.
    proposal.reload.cached_votes_up
  end

  private

    # Why the phase said no, in its own vocabulary rather than assumed. Hardcoded
    # to :not_verified, someone refused because the phase had closed or because
    # they live outside the eligible area was told their account needed verifying.
    #
    # Costs nothing extra to ask a second time — Proposal#votable_by? delegates to
    # this same phase, and ProjektPhase#permission_problem memoizes per user and
    # location, so this reads back the verdict that just refused.
    def refusal
      projekt_phase = proposal.projekt_phase

      projekt_phase&.permission_problem(@user, location: :votes_component) || :not_verified
    end

    def proposal
      return @proposal if defined?(@proposal)

      @proposal = ::Proposal.not_retired.find_by(id: @proposal_id)
    end
end
