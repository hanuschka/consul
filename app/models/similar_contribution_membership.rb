class SimilarContributionMembership < ApplicationRecord
  belongs_to :similar_contribution_group
  belongs_to :contribution, polymorphic: true

  # Relevance and reason describe the pair that first put a contribution in the
  # set, so an existing member keeps its own -- only its group moves.
  def self.attach(group:, contribution:, relevance:, reason:)
    membership = find_or_initialize_by(
      contribution_type: contribution.class.base_class.name,
      contribution_id: contribution.id
    )

    membership.similar_contribution_group = group

    if membership.new_record?
      membership.relevance = relevance
      membership.reason = reason
    end

    membership.save!

    membership
  end
end
