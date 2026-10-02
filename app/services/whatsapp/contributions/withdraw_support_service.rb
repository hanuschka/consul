class Whatsapp::Contributions::WithdrawSupportService < ApplicationService
  # Takes a citizen's support for one proposal back, and does it the way the projekt
  # page does: the vote goes and so does the follow that was created beside it.
  # Unvoting alone would leave them being notified about a contribution they have
  # just stopped supporting.
  #
  # The proposal is resolved and re-checked here rather than trusted from whoever
  # asked, for the same reason registering one is: the id can come from a pill sent
  # days ago, and by now the proposal can have been retired.
  #
  # What is deliberately not asked is whether the phase would let them vote. The
  # platform gates taking a support back on the proposal being published and nothing
  # else, and it has to: a phase with a support limit refuses every vote once the
  # limit is reached, so a withdrawal behind that check would be refused at exactly
  # the moment it is the only way back under the limit.
  #
  # Returns the count as it stands after the write, or a symbol naming what stopped
  # it. The caller turns that into words.
  def initialize(proposal_id:, user:)
    @proposal_id = proposal_id
    @user = user
  end

  def call
    return :not_linked if @user.blank?
    return :gone if proposal.blank?
    return :not_supported if !proposal.voted_up_by?(@user)

    proposal.unvote_by(@user)
    proposal.reload

    # Asked of the vote rather than trusted from the call, the same way registering
    # one is: a count reported off a write that did not happen is the one answer
    # worse than a refusal.
    return :not_withdrawn if proposal.voted_up_by?(@user)

    ::Follow.find_by(user: @user, followable: proposal)&.destroy!

    # Read back after the write rather than decremented in Ruby, the same way it is
    # after a support goes in: the counter cache is what the projekt page shows, and
    # a number in the chat that disagrees with the page is worse than no number at
    # all.
    proposal.cached_votes_up
  end

  private

    def proposal
      return @proposal if defined?(@proposal)

      @proposal = ::Proposal.not_retired.find_by(id: @proposal_id)
    end
end
