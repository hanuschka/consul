class SimilarContributions::StoredCounts < ApplicationService
  def initialize(resources)
    @resources = Array(resources)
  end

  # How many other contributions share each one's stored duplicate set. Two
  # queries for the whole page rather than one per row, because the admin
  # tables render this beside every title.
  def call
    return {} if memberships.empty?

    memberships.to_h do |membership|
      [membership.contribution_id, group_sizes.fetch(membership.similar_contribution_group_id, 1) - 1]
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

    def group_sizes
      @group_sizes ||=
        SimilarContributionMembership
          .where(similar_contribution_group_id: memberships.map(&:similar_contribution_group_id).uniq)
          .group(:similar_contribution_group_id)
          .count
    end
end
