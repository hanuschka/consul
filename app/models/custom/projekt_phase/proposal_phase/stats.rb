class ProjektPhase::ProposalPhase::Stats < ProjektPhase::Stats
  def self.stats_methods
    %i[
      visible_proposals_count
      proposal_authors_count
      unique_supporters_count
      total_votes_count
      online_votes_count
      offline_votes_count
      visible_comments_count
      reported_proposals_count
    ]
  end

  def visible_proposals_count
    proposals.count
  end

  def proposal_authors_count
    proposals.select(:author_id).distinct.count
  end

  def unique_supporters_count
    supports.select(:voter_id).distinct.count
  end

  def total_votes_count
    online_votes_count + offline_votes_count
  end

  def online_votes_count
    supports.count
  end

  def offline_votes_count
    proposals.sum(:officing_bulk_votes)
  end

  def visible_comments_count
    comments.where(hidden_at: nil).count
  end

  def reported_proposals_count
    proposals.with_hidden.flagged.select(:id).distinct.count
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
