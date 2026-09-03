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
  def call
    ActiveRecord::Base.transaction do
      SimilarContributionExclusion.record(resource, excluded, admin)

      excluded.similar_contribution_membership&.destroy!
    end
  end

  private

    attr_reader :resource, :excluded, :admin
end
