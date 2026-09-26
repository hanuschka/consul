class SimilarContributions::StoredGroup < ApplicationService
  def initialize(resource)
    @resource = resource
  end

  # The stored duplicate set as ranked matches, so the admin list and the badge
  # popup read the same records the citizen's check produced -- no AI call on a
  # page view.
  #
  # This projekt's own members come first and the matches from the further
  # projekts the phase selected follow, each block ordered by relevance: staff
  # read the current round before the earlier ones.
  def call
    peer_matches + reference_matches
  end

  private

    attr_reader :resource

    def peer_matches
      resource
        .similar_contribution_peers
        .to_a
        .map { |peer| match_for(peer, memberships_by_contribution_id[peer.id]) }
        .sort_by { |match| -match.relevance }
    end

    # Re-read through the selected projekts rather than by bare id, mirroring
    # StoredMatches: a projekt unpublished after the reference was recorded is
    # no longer one staff are shown matches from.
    def reference_matches
      return [] if references.empty?

      referenced_by_id = referenced_resources.index_by(&:id)

      references
        .filter_map do |reference|
          referenced = referenced_by_id[reference.contribution_id]
          next if referenced.nil?

          match_for(referenced, reference)
        end
        .sort_by { |match| -match.relevance }
    end

    def match_for(matched, entry)
      SimilarContributions::Ranking::Match.new(
        resource: matched,
        relevance: entry&.relevance.to_i,
        reason: entry&.reason
      )
    end

    def group
      return @group if defined?(@group)

      @group = resource.similar_contribution_group
    end

    def contribution_type
      resource.class.base_class.name
    end

    def references
      @references ||=
        if group.nil?
          []
        else
          group
            .similar_contribution_references
            .where(contribution_type: contribution_type)
            .order(relevance: :desc, id: :asc)
            .limit(SimilarContributionsCheckable::PEERS_LIMIT)
            .to_a
        end
    end

    def referenced_resources
      projekt_phase = SimilarContributions::Scopes.projekt_phase_of(resource)

      SimilarContributions::Scopes
        .projekts_presentation_relation(
          resource, projekt_phase&.published_similar_search_projekts.to_a
        )
        .where(id: references.map(&:contribution_id))
    end

    def memberships_by_contribution_id
      @memberships_by_contribution_id ||=
        if group.nil?
          {}
        else
          SimilarContributionMembership
            .where(similar_contribution_group_id: group.id)
            .index_by(&:contribution_id)
        end
    end
end
