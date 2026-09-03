module SimilarContributionsCheckable
  extend ActiveSupport::Concern

  # A duplicate set grows for as long as people keep submitting the same
  # concern, so the records are capped where they are read -- the count beside
  # the badge still reports the whole set.
  PEERS_LIMIT = 25

  included do
    has_one :similar_contribution_membership, as: :contribution, dependent: :destroy
    has_one :similar_contribution_group, through: :similar_contribution_membership

    has_many :similar_contribution_exclusions, as: :contribution, dependent: :destroy

    enum similar_contributions_check_status: {
      pending: "pending",
      processing: "processing",
      completed: "completed",
      failed: "failed"
    }, _prefix: :similar_contributions_check
  end

  def similar_contributions_check_finished?
    similar_contributions_check_completed? || similar_contributions_check_failed?
  end

  def stored_similar_contributions_matches
    Array(similar_contributions_matches)
  end

  # The other members of the stored duplicate set. Asked by the admin badge,
  # its hover popup and the detail page, so all three report the same number.
  def similar_contribution_peers
    group = similar_contribution_group

    return contribution_class.none if group.nil?

    contribution_class
      .where(id: peer_ids_in(group))
      .includes(
        SimilarContributions::Scopes.phase_includes_for(contribution_class),
        *SimilarContributions::Scopes::PRESENTATION_INCLUDES
      )
  end

  def similar_contributions_peers_count
    group = similar_contribution_group

    return 0 if group.nil?

    group.similar_contribution_memberships.count - 1
  end

  private

    def contribution_class
      self.class.base_class
    end

    def peer_ids_in(group)
      group
        .similar_contribution_memberships
        .where(contribution_type: contribution_class.name)
        .where.not(contribution_id: id)
        .where.not(contribution_id: excluded_contribution_ids)
        .order(relevance: :desc, id: :asc)
        .limit(PEERS_LIMIT)
        .pluck(:contribution_id)
    end

    # A pair an admin has settled stays apart even when a third contribution
    # has since put both of them in the same set.
    def excluded_contribution_ids
      SimilarContributionExclusion
        .where(contribution_type: contribution_class.name, contribution_id: id)
        .where(excluded_contribution_type: contribution_class.name)
        .pluck(:excluded_contribution_id) +
        SimilarContributionExclusion
          .where(excluded_contribution_type: contribution_class.name, excluded_contribution_id: id)
          .where(contribution_type: contribution_class.name)
          .pluck(:contribution_id)
    end
end
