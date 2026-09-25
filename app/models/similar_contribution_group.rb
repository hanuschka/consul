class SimilarContributionGroup < ApplicationRecord
  belongs_to :projekt

  has_many :similar_contribution_memberships, dependent: :destroy

  # Matches found in another projekt. Kept apart from the memberships because a
  # foreign contribution stays in its own projekt's set -- see
  # SimilarContributions::RecordReferences.
  has_many :similar_contribution_references, dependent: :destroy

  def contributions
    similar_contribution_memberships.map(&:contribution).compact
  end
end
