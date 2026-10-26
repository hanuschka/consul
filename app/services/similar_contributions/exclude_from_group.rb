class SimilarContributions::ExcludeFromGroup < ApplicationService
  def initialize(resource, excluded, admin: nil)
    @resource = resource
    @excluded = excluded
    @admin = admin
  end

  # A set is transitive, so "these two are not duplicates" can only be honoured
  # by taking the excluded contribution out of the set entirely. The pair is
  # recorded as well, because the membership alone would be rebuilt by the next
  # check that scores them highly.
  #
  # A match from another projekt reaches the list as a reference and belongs to
  # its own projekt's set, so only the reference goes: destroying its membership
  # would pull it out of the set it shares with its own neighbours.
  def call
    ActiveRecord::Base.transaction do
      SimilarContributionExclusion.record(resource, excluded, admin)

      if same_projekt?
        excluded.similar_contribution_membership&.destroy!
      else
        remove_references
      end
    end
  end

  private

    attr_reader :resource, :excluded, :admin

    def same_projekt?
      projekt_id_of(resource) == projekt_id_of(excluded)
    end

    def projekt_id_of(contribution)
      SimilarContributions::Scopes.projekt_phase_of(contribution)&.projekt_id
    end

    # Both directions: the other projekt's phase may name this one as well, and
    # the decision is mutual, so a reference pointing back has to go too.
    def remove_references
      delete_reference(resource.similar_contribution_group, excluded)
      delete_reference(excluded.similar_contribution_group, resource)
    end

    def delete_reference(group, contribution)
      return if group.blank?

      SimilarContributionReference
        .where(
          similar_contribution_group_id: group.id,
          contribution_type: contribution.class.base_class.name,
          contribution_id: contribution.id
        )
        .delete_all
    end
end
