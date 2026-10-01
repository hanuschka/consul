class SimilarContributions::RecordReferences < ApplicationService
  def initialize(resource, matches)
    @resource = resource
    @matches = Array(matches)
  end

  # A match from another projekt is recorded as a reference of this projekt's
  # set, never as a member of it: memberships are unique per contribution and
  # RecordGroup merges every group a match already belongs to, so a membership
  # would swallow the earlier projekt's set into this one.
  #
  # The set is created when there is none, so a contribution whose only
  # comparable entry sits in another projekt still carries the badge.
  def call
    return if projekt.blank?
    return if joinable_matches.empty?

    ActiveRecord::Base.transaction do
      group = group_for_resource

      joinable_matches.each { |match| record(group, match) }

      group
    end
  end

  private

    attr_reader :resource, :matches

    # The same bar the memberships use: a relevance that reads as a duplicate
    # here has to read as one in the current projekt too, otherwise the same
    # score would show or hide a row depending on which projekt it came from.
    def joinable_matches
      @joinable_matches ||= matches.select do |match|
        match.relevance.to_i >= SimilarContributions::RecordGroup::JOIN_RELEVANCE &&
          !SimilarContributionExclusion.between?(resource, match.resource)
      end
    end

    def projekt
      @projekt ||= SimilarContributions::Scopes.projekt_phase_of(resource)&.projekt
    end

    def group_for_resource
      group = resource.similar_contribution_group

      return group if group.present?

      group = SimilarContributionGroup.create!(projekt: projekt)
      first_match = joinable_matches.first

      SimilarContributionMembership.attach(
        group: group,
        contribution: resource,
        relevance: first_match.relevance,
        reason: first_match.reason
      )

      resource.reload_similar_contribution_group

      group
    end

    def record(group, match)
      reference = SimilarContributionReference.find_or_initialize_by(
        similar_contribution_group_id: group.id,
        contribution_type: match.resource.class.base_class.name,
        contribution_id: match.resource.id
      )

      return if reference.persisted?

      reference.relevance = match.relevance
      reference.reason = match.reason
      reference.save!
    end
end
