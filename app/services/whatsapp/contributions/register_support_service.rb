class Whatsapp::Contributions::RegisterSupportService < ApplicationService
  # Registers a citizen's support for one proposal. The proposal is resolved and
  # re-checked here rather than trusted from whoever asked: the id can come from a
  # pill sent days ago, and by now the phase can have closed or the proposal been
  # retired.
  #
  # The refusals are carefully separated because "already supported" and "not
  # allowed to" are two different things to be told, and neither is "done". The
  # first of those is also not a dead end any more — WithdrawSupportService beside
  # this one is the way back out of it.
  #
  # The citizen's own proposal is refused as such: the bot takes no support from its
  # author. Asked after "already supported", so a support they gave on the page
  # before is answered with the way back out of it rather than with a refusal.
  #
  # Archived is asked about separately from the phase's verdict, and it has to be:
  # Proposal#register_vote guards on `votable_by?(user) && !archived?` and answers a
  # failing guard with nil, so an archived proposal took the vote silently and the
  # count read back afterwards was the one it already had. That reached the citizen
  # as a support registered against a number that never moved.
  #
  # A support also follows the contribution, the way one given on the projekt page
  # does — the citizen hears about what happens to something they backed.
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
    return :own_proposal if ::Whatsapp::ContributionFacts.written_by?(proposal, @user)
    return :archived if proposal.archived?
    return :gone if !publicly_listed?
    return refusal if !proposal.votable_by?(@user)

    proposal.register_vote(@user, "yes")
    proposal.reload

    # Proposal#register_vote answers a failing guard with nil rather than raising, so
    # "it did not happen" and "it happened" are the same return value. Asked of the
    # vote instead: whatever guard turns up on that method next, a support that did
    # not land can no longer be reported as one that did.
    return :not_registered if !proposal.voted_up_by?(@user)

    follow_proposal

    # Read back after the write rather than incremented in Ruby: the counter cache
    # is what the projekt page shows, and a number in the chat that disagrees with
    # the page is worse than no number at all.
    proposal.cached_votes_up
  end

  private

    # The follow the projekt page creates beside a support, on the same condition it
    # applies: an up/down phase's widget is agree/disagree rather than support, and a
    # "yes" cast there does not mean "keep me posted about this".
    #
    # After the vote rather than before it, which is the one place this departs from
    # the controller: a vote that does not land must not leave a follow behind
    # claiming it did.
    def follow_proposal
      return if proposal.projekt_phase&.feature?("resource.enable_up_and_down_voting")

      ::Follow.find_or_create_by!(user: @user, followable: proposal)
    end

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

    # Asked after archived rather than folded into the lookup, so an archived
    # proposal keeps its own answer. What remains — a draft, a proposal still
    # awaiting moderation — answers as gone: whether it exists is not the chat's
    # to confirm, and #votable_by? asks only about the citizen.
    def publicly_listed?
      ::Whatsapp::ReachableContributionsQuery.actionable_proposals.exists?(id: proposal.id)
    end
end
