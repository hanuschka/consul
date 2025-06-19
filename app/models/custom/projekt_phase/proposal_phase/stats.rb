class ProjektPhase::ProposalPhase::Stats < ProjektPhase::Stats
  def self.stats_methods
    super +
      %i[total_proposals total_authors total_supports total_supports_weight]
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

    def proposals
      @proposals ||= projekt_phase.proposals
    end

    stats_cache(*stats_methods)
end
