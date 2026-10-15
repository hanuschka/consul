class SimilarContributions::RecordGroup < ApplicationService
  # Higher than the score the citizen's modal displays from: a resemblance
  # worth showing someone is not automatically one worth merging two sets over,
  # and a set that has swallowed a loose match cannot be pulled apart by the
  # next check.
  JOIN_RELEVANCE = 85

  def initialize(resource, matches)
    @resource = resource
    @matches = Array(matches)
  end

  # A duplicate set is shared, not per-contribution: whichever groups the
  # matched contributions already belong to are merged into one, and the new
  # contribution joins it. That is what lets every member of the set show the
  # same list -- the one submitted first included.
  def call
    return if projekt.blank?
    return if joinable_matches.empty?

    ActiveRecord::Base.transaction do
      group = merged_group
      attach(group, resource, joinable_matches.first.relevance, joinable_matches.first.reason)

      joinable_matches.each { |match| attach(group, match.resource, match.relevance, match.reason) }

      group
    end
  end

  private

    attr_reader :resource, :matches

    # An admin who marked a pair as not duplicates has settled it: a later
    # check scoring them 100 must not put them back together.
    def joinable_matches
      @joinable_matches ||= matches.select do |match|
        match.relevance.to_i >= JOIN_RELEVANCE &&
          !SimilarContributionExclusion.between?(resource, match.resource)
      end
    end

    def projekt
      @projekt ||= SimilarContributions::Scopes.projekt_phase_of(resource)&.projekt
    end

    def merged_group
      groups = existing_groups

      return SimilarContributionGroup.create!(projekt: projekt) if groups.empty?

      survivor = groups.first
      absorb(survivor, groups.drop(1))

      survivor
    end

    def existing_groups
      memberships = SimilarContributionMembership
        .where(contribution_type: contribution_type, contribution_id: member_ids)

      SimilarContributionGroup
        .where(id: memberships.select(:similar_contribution_group_id))
        .order(:id)
        .to_a
    end

    def contribution_type
      resource.class.base_class.name
    end

    def member_ids
      joinable_matches.map { |match| match.resource.id } + [resource.id]
    end

    def absorb(survivor, absorbed_groups)
      return if absorbed_groups.empty?

      absorbed_ids = absorbed_groups.map(&:id)

      SimilarContributionMembership
        .where(similar_contribution_group_id: absorbed_ids)
        .update_all(similar_contribution_group_id: survivor.id)

      move_references(survivor, absorbed_ids)

      SimilarContributionGroup.where(id: absorbed_ids).delete_all
    end

    # The absorbed groups go through delete_all, so dependent: :destroy never
    # runs and a reference left behind would point at nothing -- dropping out of
    # the list without anyone deciding that. Both sets can already name the same
    # foreign contribution, and the pair is unique per group, so those rows are
    # dropped rather than moved.
    def move_references(survivor, absorbed_ids)
      absorbed_references = SimilarContributionReference.where(
        similar_contribution_group_id: absorbed_ids
      )

      absorbed_references
        .where("(contribution_type, contribution_id) IN (" \
               "SELECT contribution_type, contribution_id FROM similar_contribution_references " \
               "WHERE similar_contribution_group_id = ?)", survivor.id)
        .delete_all

      absorbed_references.update_all(similar_contribution_group_id: survivor.id)
    end

    def attach(group, contribution, relevance, reason)
      SimilarContributionMembership.attach(
        group: group, contribution: contribution, relevance: relevance, reason: reason
      )
    end
end
