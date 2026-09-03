class SimilarContributions::StoredGroup < ApplicationService
  def initialize(resource)
    @resource = resource
  end

  # The stored duplicate set as ranked matches, so the admin list and the badge
  # popup read the same records the citizen's check produced -- no AI call on a
  # page view.
  def call
    peers = resource.similar_contribution_peers.to_a

    return [] if peers.empty?

    peers
      .map { |peer| match_for(peer) }
      .sort_by { |match| -match.relevance }
  end

  private

    attr_reader :resource

    def match_for(peer)
      membership = memberships_by_contribution_id[peer.id]

      SimilarContributions::Ranking::Match.new(
        resource: peer,
        relevance: membership&.relevance.to_i,
        reason: membership&.reason
      )
    end

    def memberships_by_contribution_id
      @memberships_by_contribution_id ||=
        SimilarContributionMembership
          .where(similar_contribution_group_id: resource.similar_contribution_group&.id)
          .index_by(&:contribution_id)
    end
end
