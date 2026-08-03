class ProjektPhase::ProposalPhase::Stats < ProjektPhase::Stats
  def self.stats_methods
    base_stats_methods + gender_methods + age_methods + geozone_methods +
    %i[
      total_unique_participants_count
      visible_proposals_count
      proposal_authors_count
      unique_supporters_count
      total_votes_count
      online_votes_count
      offline_votes_count
      visible_comments_count
    ]
  end

  def total_participants
    participants.distinct.count
  end

  def total_unique_participants_count
    author_ids = proposals.select(:author_id).distinct.pluck(:author_id)
    voter_ids = supports.select(:voter_id).distinct.pluck(:voter_id)
    commenter_ids = comments.where(hidden_at: nil).select(:user_id).distinct.pluck(:user_id)

    (author_ids + voter_ids + commenter_ids).uniq.compact.count
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

  private

    def participant_ids
      author_ids = proposals.select(:author_id).distinct.pluck(:author_id)
      voter_ids = supports.select(:voter_id).distinct.pluck(:voter_id)
      commenter_ids = comments.where(hidden_at: nil).select(:user_id).distinct.pluck(:user_id)

      (author_ids + voter_ids + commenter_ids).uniq.compact
    end

    def supports
      @supports ||= ActsAsVotable::Vote
                      .where(
                        votable_type: "Proposal",
                        votable_id: proposals.select(:id),
                        voter_type: "User",
                        conditional: false
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
