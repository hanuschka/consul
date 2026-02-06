class ProjektPhase::ProposalPhase::Stats < ProjektPhase::Stats
  def self.stats_methods
    super +
      %i[total_proposals total_authors total_supports total_supports_weight total_comments total_hidden total_reported]
  end

  def total_participants
    participants.distinct.count
  end

  def total_proposals
    proposals.count
  end

  def total_authors
    proposals.select(:author_id).distinct.count
  end

  def total_supports
    supports.distinct.count
  end

  def total_supports_weight
    supports.sum(:vote_weight) + proposals.sum(:officing_bulk_votes)
  end

  def total_comments
    comments.count
  end

  def total_hidden
    proposals.only_hidden.count
  end

  def total_reported
    proposals.with_hidden.flagged.count
  end

  private

    def participant_ids
      supports.select(:voter_id).distinct.pluck(:voter_id)
    end

    def supports
      @supports ||= ActsAsVotable::Vote
                      .where(
                        votable_type: "Proposal",
                        votable_id: proposals.select(:id),
                        voter_type: "User"
                      )
    end

    def comments
      @comments ||= Comment.where(commentable_type: "Proposal", commentable_id: proposals.select(:id))
    end

    def proposals
      @proposals ||= projekt_phase.proposals
    end

    stats_cache(*stats_methods)
end
