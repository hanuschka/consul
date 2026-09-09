class SimilarContributions::StoredCounts < ApplicationService
  def initialize(resources)
    @resources = Array(resources)
  end

  # How many other contributions share each one's stored duplicate set, the
  # matches from further projekts included. Three queries for the whole page
  # rather than one per row, because the admin tables render this beside every
  # title.
  def call
    return {} if memberships.empty?

    memberships.to_h do |membership|
      group_id = membership.similar_contribution_group_id

      [membership.contribution_id, peers_in(group_id) + references_in(group_id)]
    end
  end

  private

    attr_reader :resources

    def memberships
      @memberships ||=
        if resources.empty?
          []
        else
          SimilarContributionMembership
            .where(contribution_type: resources.first.class.base_class.name,
                   contribution_id: resources.map(&:id))
            .to_a
        end
    end

    def peers_in(group_id)
      group_sizes.fetch(group_id, 1) - 1
    end

    def references_in(group_id)
      reference_counts.fetch(group_id, 0)
    end

    def group_ids
      @group_ids ||= memberships.map(&:similar_contribution_group_id).uniq
    end

    def group_sizes
      @group_sizes ||=
        SimilarContributionMembership
          .where(similar_contribution_group_id: group_ids)
          .group(:similar_contribution_group_id)
          .count
    end

    def reference_counts
      @reference_counts ||=
        SimilarContributionReference
          .where(similar_contribution_group_id: group_ids)
          .group(:similar_contribution_group_id)
          .count
    end
end
