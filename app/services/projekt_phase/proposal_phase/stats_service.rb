class ProjektPhase::ProposalPhase::StatsService
  def initialize(projekt_phase)
    @projekt_phase = projekt_phase
  end

  def stale?
    @projekt_phase.stats.empty?
  end

  def call
    demographics = DemographicsCalculator.new(participant_ids)

    @projekt_phase.update!(
      stats: {
        total_unique_participants_count: participant_ids.uniq.count,
        visible_proposals_count: proposals.count,
        proposal_authors_count: proposals.select(:author_id).distinct.count,
        unique_supporters_count: supports.select(:voter_id).distinct.count,
        online_votes_count: supports.count,
        offline_votes_count: proposals.sum(:officing_bulk_votes),
        total_votes_count: supports.count + proposals.sum(:officing_bulk_votes),
        visible_comments_count: visible_comments.count,
        **demographics.gender_data,
        participants_by_age: demographics.age_data,
        participants_by_geozone: demographics.geozone_data
      },
      stats_refreshed_at: Time.current
    )
  end

  private

    def proposals
      @proposals ||= @projekt_phase.proposals
    end

    def supports
      @supports ||=
        ActsAsVotable::Vote
          .where(
            votable_type: "Proposal",
            votable_id: proposals.select(:id),
            voter_type: "User"
          )
    end

    def visible_comments
      @visible_comments ||= Comment.where(
        commentable_type: "Proposal",
        commentable_id: proposals.select(:id),
        hidden_at: nil
      )
    end

    def participant_ids
      @participant_ids ||= begin
        author_ids = proposals.select(:author_id).distinct.pluck(:author_id)
        voter_ids = supports.select(:voter_id).distinct.pluck(:voter_id)
        commenter_ids = visible_comments.select(:user_id).distinct.pluck(:user_id)
        (author_ids + voter_ids + commenter_ids).uniq.compact
      end
    end
end
